/**
 * 订阅配置合并。契约见仓库 client/shared/SUBSCRIPTION.md 第 3 节：
 * 取服务端 JSON 的 outbounds 与 route.final，其余取客户端模板。
 * Windows MVP：只用 mixed 入站 + 系统代理，暂不启用 TUN 入站
 *（TUN 需管理员权限 + wintun 驱动，第二步再做）。
 */
import template from "./assets/singbox-template.json";

export function mergeConfig(server: any): any {
  const merged: any = JSON.parse(JSON.stringify(template));
  merged.outbounds = [
    ...(server?.outbounds ?? []),
    { type: "dns", tag: "dns-out" },
  ];
  merged.route = {
    ...(merged.route ?? {}),
    final: server?.route?.final ?? "proxy",
  };
  merged.inbounds = (merged.inbounds ?? []).filter(
    (i: any) => i.type !== "tun",
  );
  merged.log = { level: "info" };
  return merged;
}

const RESERVED_TAGS = new Set(["auto", "proxy", "direct", "dns-out"]);

/** 从合并后的配置里取节点名（排除 auto/proxy/direct/dns-out）。 */
export function extractNodes(config: any): string[] {
  return (config?.outbounds ?? [])
    .map((o: any) => o.tag as string)
    .filter((t: string) => t && !RESERVED_TAGS.has(t));
}

/** 是否有可用节点（无节点 = 套餐过期或未购买）。 */
export function hasNodes(config: any): boolean {
  return extractNodes(config).length > 0;
}
