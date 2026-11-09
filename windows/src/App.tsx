import { useCallback, useEffect, useRef, useState } from "react";
import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";
import {
  clashAlive,
  fetchSubscription,
  getCurrentProxy,
  getDelay,
  login,
  NeedTotpError,
  setProxy,
  subscribeTraffic,
  type SubInfo,
  type UserInfo,
} from "./api";
import { extractNodes, hasNodes, mergeConfig } from "./singbox";

const AUTH_KEY = "zgltvpn-auth-v1";

interface Auth {
  email: string;
  token: string;
  subToken: string;
}

interface StatusPayload {
  running: boolean;
  node: string;
}

function loadAuth(): Auth | null {
  try {
    const raw = localStorage.getItem(AUTH_KEY);
    return raw ? (JSON.parse(raw) as Auth) : null;
  } catch {
    return null;
  }
}

function formatBytes(n: number): string {
  if (!n || n <= 0) return "0 B";
  const units = ["B", "KB", "MB", "GB", "TB"];
  let v = n;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return `${v.toFixed(v >= 100 ? 0 : 1)} ${units[i]}`;
}

function formatDate(tsMs: number): string {
  if (!tsMs) return "—";
  return new Date(tsMs).toLocaleDateString("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  });
}

export default function App() {
  const [auth, setAuth] = useState<Auth | null>(() => loadAuth());
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [totp, setTotp] = useState("");
  const [needTotp, setNeedTotp] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");

  const [user, setUser] = useState<UserInfo | null>(null);
  const [config, setConfig] = useState<any | null>(null);
  const [nodes, setNodes] = useState<string[]>([]);
  const [userinfo, setUserinfo] = useState<SubInfo | null>(null);
  const [subAt, setSubAt] = useState<number>(0);

  const [running, setRunning] = useState(false);
  const [currentNode, setCurrentNode] = useState("auto");
  const [up, setUp] = useState(0);
  const [down, setDown] = useState(0);
  const [delayMs, setDelayMs] = useState<number | null>(null);
  const [testing, setTesting] = useState(false);
  const [logs, setLogs] = useState<string[]>([]);
  const [showLogs, setShowLogs] = useState(false);

  const trafficStopRef = useRef<(() => void) | null>(null);
  const authRef = useRef(auth);
  authRef.current = auth;

  const pushLog = useCallback((line: string) => {
    setLogs((prev) => [...prev.slice(-99), line]);
  }, []);

  const stopTraffic = useCallback(() => {
    trafficStopRef.current?.();
    trafficStopRef.current = null;
    setUp(0);
    setDown(0);
  }, []);

  const startTraffic = useCallback(() => {
    stopTraffic();
    trafficStopRef.current = subscribeTraffic((u, d) => {
      setUp(u);
      setDown(d);
    });
  }, [stopTraffic]);

  /** 拉订阅 → 合并 → 写本地配置。成功返回合并后的配置。 */
  const refreshSubscription = useCallback(async (): Promise<any> => {
    const a = authRef.current;
    if (!a) throw new Error("请先登录");
    const { config: serverConfig, userinfo: info } = await fetchSubscription(
      a.subToken,
    );
    const merged = mergeConfig(serverConfig);
    await invoke("save_config", { config: merged });
    setConfig(merged);
    setNodes(extractNodes(merged));
    setUserinfo(info);
    setSubAt(Date.now());
    if (!hasNodes(merged)) {
      setNotice("套餐已过期或没有可用节点，请先续费");
    } else {
      setNotice("");
    }
    return merged;
  }, []);

  const doLogin = async () => {
    if (!email.trim() || !password) {
      setError("请输入邮箱和密码");
      return;
    }
    setBusy(true);
    setError("");
    try {
      const res = await login(email.trim(), password, needTotp ? totp : undefined);
      const next: Auth = {
        email: email.trim(),
        token: res.token,
        subToken: res.user.sub_token,
      };
      localStorage.setItem(AUTH_KEY, JSON.stringify(next));
      setAuth(next);
      setUser(res.user);
      setNeedTotp(false);
      setTotp("");
      await refreshSubscription();
    } catch (e: any) {
      if (e instanceof NeedTotpError) {
        setNeedTotp(true);
        setError("账号开启了两步验证，请输入 6 位验证码");
      } else {
        setError(e?.message || "登录失败");
      }
    } finally {
      setBusy(false);
    }
  };

  const doLogout = async () => {
    try {
      await invoke("stop_vpn");
    } catch {
      // 忽略
    }
    stopTraffic();
    localStorage.removeItem(AUTH_KEY);
    setAuth(null);
    setUser(null);
    setConfig(null);
    setNodes([]);
    setUserinfo(null);
    setRunning(false);
    setCurrentNode("auto");
    setError("");
    setNotice("");
  };

  const doConnect = async () => {
    setBusy(true);
    setError("");
    try {
      let cfg = config;
      if (!cfg) cfg = await refreshSubscription();
      if (!hasNodes(cfg)) {
        setError("没有可用节点，套餐可能已过期");
        return;
      }
      await invoke("start_vpn");
      // 等核心的 Clash API 就绪（最多约 15 秒）
      let alive = false;
      for (let i = 0; i < 30; i++) {
        if (await clashAlive()) {
          alive = true;
          break;
        }
        await new Promise((r) => setTimeout(r, 500));
      }
      if (!alive) {
        setError("核心已启动但控制接口无响应，请查看日志");
        return;
      }
      setRunning(true);
      const now = await getCurrentProxy();
      setCurrentNode(now);
      await invoke("set_current_node", { node: now });
      startTraffic();
    } catch (e: any) {
      setError(e?.message || String(e) || "连接失败");
    } finally {
      setBusy(false);
    }
  };

  const doDisconnect = async () => {
    setBusy(true);
    try {
      await invoke("stop_vpn");
    } catch (e: any) {
      setError(e?.message || String(e));
    } finally {
      stopTraffic();
      setRunning(false);
      setBusy(false);
    }
  };

  const doSwitchNode = async (name: string) => {
    if (!running) {
      setCurrentNode(name);
      await invoke("set_current_node", { node: name }).catch(() => {});
      return;
    }
    setError("");
    try {
      await setProxy(name);
      setCurrentNode(name);
      await invoke("set_current_node", { node: name });
      setDelayMs(null);
    } catch (e: any) {
      setError(e?.message || "切换节点失败");
    }
  };

  const doTestDelay = async () => {
    setTesting(true);
    setDelayMs(null);
    try {
      const ms = await getDelay(currentNode);
      setDelayMs(ms);
    } catch {
      setDelayMs(-1);
    } finally {
      setTesting(false);
    }
  };

  // 启动时：同步后端状态 + 监听托盘/核心事件
  useEffect(() => {
    let unlistenStatus: (() => void) | undefined;
    let unlistenLog: (() => void) | undefined;
    void (async () => {
      try {
        const st = await invoke<StatusPayload>("get_status");
        setRunning(st.running);
        setCurrentNode(st.node || "auto");
        if (st.running && (await clashAlive())) {
          setCurrentNode(await getCurrentProxy());
          startTraffic();
        }
      } catch {
        // 忽略
      }
      unlistenStatus = await listen<StatusPayload>("vpn-status", (e) => {
        setRunning(e.payload.running);
        if (e.payload.node) setCurrentNode(e.payload.node);
        if (!e.payload.running) stopTraffic();
      });
      unlistenLog = await listen<string>("vpn-log", (e) => {
        pushLog(typeof e.payload === "string" ? e.payload : JSON.stringify(e.payload));
      });
    })();
    return () => {
      unlistenStatus?.();
      unlistenLog?.();
      trafficStopRef.current?.();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // 登录后（刷新页面）自动拉一次订阅
  useEffect(() => {
    if (auth && !config) {
      void refreshSubscription().catch((e: any) =>
        setError(e?.message || "拉取订阅失败"),
      );
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [auth]);

  const remaining =
    userinfo && userinfo.total > 0
      ? Math.max(0, userinfo.total - userinfo.download)
      : user && user.traffic_total > 0
        ? Math.max(0, user.traffic_total - user.traffic_used)
        : null;
  const expireTs = userinfo?.expire
    ? userinfo.expire * 1000
    : user?.expires ?? 0;

  if (!auth) {
    return (
      <div className="page login-page">
        <div className="card login-card">
          <div className="logo">Z</div>
          <h1>ZGLTVPN</h1>
          <p className="sub">登录后一键连接</p>
          <label>
            邮箱
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="you@example.com"
              onKeyDown={(e) => e.key === "Enter" && void doLogin()}
            />
          </label>
          <label>
            密码
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder="密码"
              onKeyDown={(e) => e.key === "Enter" && void doLogin()}
            />
          </label>
          {needTotp && (
            <label>
              两步验证码
              <input
                type="text"
                inputMode="numeric"
                maxLength={6}
                value={totp}
                onChange={(e) => setTotp(e.target.value.replace(/\D/g, ""))}
                placeholder="6 位数字"
                onKeyDown={(e) => e.key === "Enter" && void doLogin()}
              />
            </label>
          )}
          {error && <div className="error">{error}</div>}
          <button className="primary" onClick={() => void doLogin()} disabled={busy}>
            {busy ? "登录中…" : "登录"}
          </button>
          <p className="hint">账号就是网站上的账号；登录信息只保存在本机。</p>
        </div>
      </div>
    );
  }

  return (
    <div className="page">
      <header className="topbar">
        <div className="brand">
          <span className="logo small">Z</span>
          <span>ZGLTVPN</span>
        </div>
        <div className="userline">
          <span>{auth.email}</span>
          <button className="link" onClick={() => void doLogout()}>
            退出登录
          </button>
        </div>
      </header>

      {error && <div className="error banner">{error}</div>}
      {notice && <div className="notice banner">{notice}</div>}

      <main className="main">
        <section className="connect-card">
          <button
            className={`bigbtn ${running ? "on" : "off"}`}
            onClick={() => void (running ? doDisconnect() : doConnect())}
            disabled={busy}
          >
            {busy ? "处理中…" : running ? "断开连接" : "连接"}
          </button>
          <div className={`status ${running ? "ok" : ""}`}>
            <span className="dot" />
            {running ? "已连接" : "未连接"}
            {running && delayMs !== null && delayMs >= 0 && (
              <span className="delay"> · {delayMs} ms</span>
            )}
          </div>

          <label className="nodelabel">
            当前节点
            <select
              value={currentNode}
              onChange={(e) => void doSwitchNode(e.target.value)}
            >
              <option value="auto">自动选择（最快）</option>
              {nodes.map((n) => (
                <option key={n} value={n}>
                  {n}
                </option>
              ))}
            </select>
          </label>
          <button
            className="secondary"
            onClick={() => void doTestDelay()}
            disabled={!running || testing}
          >
            {testing ? "测速中…" : "测当前节点延迟"}
          </button>
        </section>

        <section className="stats">
          <div className="stat">
            <span className="k">上行</span>
            <span className="v">{formatBytes(up)}/s</span>
          </div>
          <div className="stat">
            <span className="k">下行</span>
            <span className="v">{formatBytes(down)}/s</span>
          </div>
          <div className="stat">
            <span className="k">剩余流量</span>
            <span className="v">
              {remaining === null ? "—" : formatBytes(remaining)}
            </span>
          </div>
          <div className="stat">
            <span className="k">到期日</span>
            <span className="v">{formatDate(expireTs)}</span>
          </div>
        </section>

        <section className="actions">
          <button
            className="secondary"
            onClick={() => {
              setBusy(true);
              setError("");
              void refreshSubscription()
                .then(() => setNotice("订阅已刷新"))
                .catch((e: any) => setError(e?.message || "刷新订阅失败"))
                .finally(() => setBusy(false));
            }}
            disabled={busy}
          >
            刷新订阅
          </button>
          <button
            className="secondary"
            onClick={() => setShowLogs((v) => !v)}
          >
            {showLogs ? "隐藏日志" : "查看日志"}
          </button>
          {subAt > 0 && (
            <span className="subat">
              订阅更新于 {new Date(subAt).toLocaleTimeString("zh-CN")}
            </span>
          )}
        </section>

        {showLogs && (
          <pre className="logs">
            {logs.length ? logs.join("\n") : "暂无日志"}
          </pre>
        )}
      </main>
    </div>
  );
}
