import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { createTestHarness, request, seedUser, type TestHarness } from "./helpers";

type TagRow = {
	id: string;
	userId: string;
	name: string;
	color: string;
	createdAt: string;
};

describe("tags API", () => {
	let h: TestHarness;

	beforeEach(async () => {
		h = await createTestHarness();
		await seedUser(h, "u1");
		await seedUser(h, "u2");
		h.asUser("u1");
	});

	afterEach(async () => {
		await h.close();
	});

	describe("POST /api/tags", () => {
		test("creates a tag with valid body", async () => {
			const res = await request(h, "POST", "/api/tags", {
				name: "Work",
				color: "#ff0000",
			});
			expect(res.status).toBe(201);
			const body = (await res.json()) as TagRow;
			expect(body.name).toBe("Work");
			expect(body.color).toBe("#ff0000");
			expect(body.userId).toBe("u1");
		});

		test("rejects invalid color format", async () => {
			const res = await request(h, "POST", "/api/tags", {
				name: "Bad",
				color: "red",
			});
			expect(res.status).toBe(400);
		});

		test("rejects empty name", async () => {
			const res = await request(h, "POST", "/api/tags", {
				name: "",
				color: "#000000",
			});
			expect(res.status).toBe(400);
		});

		test("allows duplicate tag names per user (no unique constraint)", async () => {
			const r1 = await request(h, "POST", "/api/tags", {
				name: "Same",
				color: "#111111",
			});
			expect(r1.status).toBe(201);
			const r2 = await request(h, "POST", "/api/tags", {
				name: "Same",
				color: "#222222",
			});
			expect(r2.status).toBe(201);
		});

		test("rejects unauthenticated requests", async () => {
			const h2 = await createTestHarness();
			try {
				const res = await request(h2, "POST", "/api/tags", {
					name: "X",
					color: "#000000",
				});
				expect(res.status).toBe(401);
			} finally {
				await h2.close();
			}
		});
	});

	describe("GET /api/tags", () => {
		test("returns tags only for the current user", async () => {
			await request(h, "POST", "/api/tags", { name: "A", color: "#aaaaaa" });
			h.asUser("u2");
			await request(h, "POST", "/api/tags", { name: "B", color: "#bbbbbb" });

			h.asUser("u1");
			const res = await request(h, "GET", "/api/tags");
			expect(res.status).toBe(200);
			const body = (await res.json()) as TagRow[];
			expect(body.length).toBe(1);
			expect(body[0].name).toBe("A");
		});

		test("returns empty array when user has no tags", async () => {
			const res = await request(h, "GET", "/api/tags");
			expect(res.status).toBe(200);
			const body = (await res.json()) as TagRow[];
			expect(body).toEqual([]);
		});
	});

	describe("PUT /api/tags/:id", () => {
		test("updates name only", async () => {
			const created = await (
				await request(h, "POST", "/api/tags", {
					name: "Old",
					color: "#abcdef",
				})
			).json();
			const res = await request(h, "PUT", `/api/tags/${created.id}`, {
				name: "New",
			});
			expect(res.status).toBe(200);
			const body = (await res.json()) as TagRow;
			expect(body.name).toBe("New");
			expect(body.color).toBe("#abcdef");
		});

		test("rejects invalid uuid", async () => {
			const res = await request(h, "PUT", "/api/tags/not-a-uuid", {
				name: "X",
			});
			expect(res.status).toBe(400);
		});

		test("returns 404 when tag belongs to another user", async () => {
			h.asUser("u2");
			const other = await (
				await request(h, "POST", "/api/tags", {
					name: "Other",
					color: "#000000",
				})
			).json();
			h.asUser("u1");
			const res = await request(h, "PUT", `/api/tags/${other.id}`, {
				name: "Hack",
			});
			expect(res.status).toBe(404);
		});
	});

	describe("DELETE /api/tags/:id", () => {
		test("deletes the tag", async () => {
			const created = await (
				await request(h, "POST", "/api/tags", {
					name: "Doomed",
					color: "#deadbe",
				})
			).json();
			const res = await request(h, "DELETE", `/api/tags/${created.id}`);
			expect(res.status).toBe(204);

			const list = (await (await request(h, "GET", "/api/tags")).json()) as TagRow[];
			expect(list.length).toBe(0);
		});

		test("cascade-deletes pin_tags rows", async () => {
			const tag = await (
				await request(h, "POST", "/api/tags", {
					name: "T",
					color: "#000000",
				})
			).json();
			const pin = await (
				await request(h, "POST", "/api/pins", {
					latitude: 35.0,
					longitude: 139.0,
				})
			).json();
			await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [tag.id],
			});

			await request(h, "DELETE", `/api/tags/${tag.id}`);

			const after = (await (await request(h, "GET", "/api/pins")).json()) as {
				id: string;
				tagIds: string[];
			}[];
			const updated = after.find((p) => p.id === pin.id);
			expect(updated?.tagIds).toEqual([]);
		});
	});
});
