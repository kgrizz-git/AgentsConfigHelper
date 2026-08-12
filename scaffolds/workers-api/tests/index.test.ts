import { describe, it, expect } from "vitest";
import worker from "../src/index";

describe("Worker", () => {
  it("responds to root path", async () => {
    const request = new Request("https://example.com/");
    const env = { ENVIRONMENT: "test" };
    const response = await worker.fetch(request, env);
    
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data.message).toBe("Hello from Cloudflare Workers!");
  });

  it("responds to health check", async () => {
    const request = new Request("https://example.com/health");
    const env = { ENVIRONMENT: "test" };
    const response = await worker.fetch(request, env);
    
    expect(response.status).toBe(200);
    const data = await response.json();
    expect(data.status).toBe("healthy");
  });

  it("returns 404 for unknown routes", async () => {
    const request = new Request("https://example.com/unknown");
    const env = { ENVIRONMENT: "test" };
    const response = await worker.fetch(request, env);
    
    expect(response.status).toBe(404);
  });
});
