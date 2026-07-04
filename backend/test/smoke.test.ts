import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { createTestHarness, request, seedUser, type TestHarness } from "./helpers";

describe("smoke", () => {
	let h: TestHarness;

	beforeEach(async () => {
		h = await createTestHarness();
		await seedUser(h, "u1");
	});

	afterEach(async () => {
		await h.close();
	});

	test("health endpoint works without auth", async () => {
		const res = await request(h, "GET", "/health");
		expect(res.status).toBe(200);
		const body = (await res.json()) as { status: string };
		expect(body.status).toBe("ok");
	});

	test("authenticated /api/me returns the injected user id", async () => {
		h.asUser("u1");
		const res = await request(h, "GET", "/api/me");
		expect(res.status).toBe(200);
		const body = (await res.json()) as { userId: string };
		expect(body.userId).toBe("u1");
	});

	test("unauthenticated request to /api/me is rejected", async () => {
		const res = await request(h, "GET", "/api/me");
		expect(res.status).toBe(401);
	});
});
