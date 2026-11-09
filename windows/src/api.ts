/**
 * 与 ZGLTVPN 后端（Cloudflare Worker）以及本地 sing-box Clash API 的通信。
 * 契约见仓库 client/shared/SUBSCRIPTION.md。
 */

const API_BASE = "https://vpn.zgltvpn.workers.dev";
const CLASH_BASE = "http://127.0.0.1:9090";

export interface UserInfo {
  sub_token: string;
  expires: number; // 套餐到期毫秒时间戳
  traffic_total: number; // 流量总额（字节）
  traffic_used: number; // 已用流量（字节）
  email?: string;
  plan_name?: string;
}

export interface LoginResult {
  token: string;
  user: UserInfo;
}

export interface SubInfo {
  upload: number;
  download: number;
  total: number;
  expire: number; // 到期 unix 秒
}

export class NeedTotpError extends Error {
  constructor() {
    super("need_totp");
    this.name = "NeedTotpError";
  }
}

function loginErrorMessage(status: number, body: any): string {
  if (status === 401) return "邮箱或密码错误";
  if (status === 429) return "尝试过多，15 分钟后再试";
  if (status === 403) return "账号已被封禁";
  return body?.message || `登录失败（${status}）`;
}

/** 登录。成功返回 {token, user}；开了 TOTP 时抛 NeedTotpError。 */
export async function login(
  email: string,
  password: string,
  totp?: string,
): Promise<LoginResult> {
  const res = await fetch(`${API_BASE}/api/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(
      totp ? { email, password, totp } : { email, password },
    ),
  });
  const data: any = await res.json().catch(() => ({}));
  if (data?.need_totp) throw new NeedTotpError();
  if (!res.ok) throw new Error(loginErrorMessage(res.status, data));
  if (!data?.user?.sub_token) throw new Error("登录返回异常，请重试");
  return data as LoginResult;
}

export function parseUserinfo(header: string): SubInfo {
  const out: SubInfo = { upload: 0, download: 0, total: 0, expire: 0 };
  for (const part of header.split(";")) {
    const [k, v] = part.trim().split("=");
    if (k === "upload" || k === "download" || k === "total" || k === "expire") {
      out[k] = Number(v) || 0;
    }
  }
  return out;
}

/** 拉订阅（singbox 格式）。返回服务端配置 JSON 与 subscription-userinfo 头。 */
export async function fetchSubscription(
  subToken: string,
): Promise<{ config: any; userinfo: SubInfo | null }> {
  const res = await fetch(
    `${API_BASE}/sub/${encodeURIComponent(subToken)}?format=singbox`,
  );
  if (res.status === 404) throw new Error("订阅无效，请重新登录");
  if (res.status === 403) throw new Error("账号已被封禁");
  if (!res.ok) throw new Error(`拉取订阅失败（${res.status}）`);
  const config = await res.json();
  const header = res.headers.get("subscription-userinfo");
  return { config, userinfo: header ? parseUserinfo(header) : null };
}

/** Clash API 是否可达（核心是否在跑）。 */
export async function clashAlive(): Promise<boolean> {
  try {
    const res = await fetch(`${CLASH_BASE}/version`, {
      signal: AbortSignal.timeout(2000),
    });
    return res.ok;
  } catch {
    return false;
  }
}

/** 当前选中的节点（selector "proxy" 的 now 值，默认 auto）。 */
export async function getCurrentProxy(): Promise<string> {
  try {
    const res = await fetch(`${CLASH_BASE}/proxies/proxy`);
    if (!res.ok) return "auto";
    const data = await res.json();
    return data.now || "auto";
  } catch {
    return "auto";
  }
}

/** 切换节点。 */
export async function setProxy(name: string): Promise<void> {
  const res = await fetch(`${CLASH_BASE}/proxies/proxy`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ name }),
  });
  if (!res.ok) throw new Error("切换节点失败");
}

/** 测指定节点的延迟（毫秒）。 */
export async function getDelay(name: string): Promise<number> {
  const url = `${CLASH_BASE}/proxies/${encodeURIComponent(
    name,
  )}/delay?timeout=5000&url=${encodeURIComponent(
    "https://www.gstatic.com/generate_204",
  )}`;
  const res = await fetch(url);
  if (!res.ok) throw new Error("测速失败");
  const data = await res.json();
  return data.delay as number;
}

/**
 * 订阅 Clash API 的实时流量流（每秒推送一次 {up, down}，单位字节/秒）。
 * 返回取消函数。
 */
export function subscribeTraffic(
  onData: (up: number, down: number) => void,
): () => void {
  const ctrl = new AbortController();
  void (async () => {
    try {
      const res = await fetch(`${CLASH_BASE}/traffic`, {
        signal: ctrl.signal,
      });
      if (!res.body) return;
      const reader = res.body.getReader();
      const dec = new TextDecoder();
      let buf = "";
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        buf += dec.decode(value, { stream: true });
        let idx: number;
        while ((idx = buf.indexOf("\n")) >= 0) {
          const line = buf.slice(0, idx).trim();
          buf = buf.slice(idx + 1);
          if (!line) continue;
          try {
            const d = JSON.parse(line);
            onData(d.up ?? 0, d.down ?? 0);
          } catch {
            // 忽略半截行
          }
        }
      }
    } catch {
      // 流结束（断开或核心停止），属正常情况
    }
  })();
  return () => ctrl.abort();
}
