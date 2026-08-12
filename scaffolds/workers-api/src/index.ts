export interface Env {
  ENVIRONMENT: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    const path = url.pathname;

    // Simple routing
    if (path === "/") {
      return Response.json({
        message: "Hello from Cloudflare Workers!",
        environment: env.ENVIRONMENT,
      });
    }

    if (path === "/health") {
      return Response.json({ status: "healthy" });
    }

    // 404 for unknown routes
    return Response.json({ error: "Not found" }, { status: 404 });
  },
};
