import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { createTestHarness, request, seedUser, type TestHarness } from "./helpers";

type PinRow = {
	id: string;
	userId: string;
	mapId: string | null;
	latitude: number;
	longitude: number;
	createdAt: string;
	tagIds: string[];
};

async function createMap(h: TestHarness, name = "M"): Promise<string> {
	const r = await request(h, "POST", "/api/maps", { name });
	return ((await r.json()) as { id: string }).id;
}

async function createTag(h: TestHarness, name = "T"): Promise<string> {
	const r = await request(h, "POST", "/api/tags", {
		name,
		color: "#000000",
	});
	return ((await r.json()) as { id: string }).id;
}

describe("pins API", () => {
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

	describe("POST /api/pins", () => {
		test("creates a pin without mapId", async () => {
			const res = await request(h, "POST", "/api/pins", {
				latitude: 35.5,
				longitude: 139.7,
			});
			expect(res.status).toBe(201);
			const body = (await res.json()) as PinRow;
			expect(body.latitude).toBe(35.5);
			expect(body.tagIds).toEqual([]);
		});

		test("creates a pin with valid mapId", async () => {
			const mapId = await createMap(h);
			const res = await request(h, "POST", "/api/pins", {
				latitude: 1,
				longitude: 2,
				mapId,
			});
			expect(res.status).toBe(201);
			expect(((await res.json()) as PinRow).mapId).toBe(mapId);
		});

		test("rejects pin with another user's mapId", async () => {
			h.asUser("u2");
			const otherMap = await createMap(h, "Other");
			h.asUser("u1");
			const res = await request(h, "POST", "/api/pins", {
				latitude: 1,
				longitude: 2,
				mapId: otherMap,
			});
			expect(res.status).toBe(404);
		});

		test("rejects invalid coordinates", async () => {
			const res = await request(h, "POST", "/api/pins", {
				latitude: "nope",
				longitude: 1,
			});
			expect(res.status).toBe(400);
		});
	});

	describe("POST /api/pins/batch", () => {
		test("creates multiple pins atomically", async () => {
			const res = await request(h, "POST", "/api/pins/batch", {
				pins: [
					{ latitude: 1, longitude: 2 },
					{ latitude: 3, longitude: 4 },
				],
			});
			expect(res.status).toBe(201);
			const body = (await res.json()) as PinRow[];
			expect(body.length).toBe(2);
		});

		test("rejects batch when any pin has another user's mapId", async () => {
			h.asUser("u2");
			const otherMap = await createMap(h, "Other");
			h.asUser("u1");
			const myMap = await createMap(h, "Mine");
			const res = await request(h, "POST", "/api/pins/batch", {
				pins: [
					{ latitude: 1, longitude: 2, mapId: myMap },
					{ latitude: 3, longitude: 4, mapId: otherMap },
				],
			});
			expect(res.status).toBe(404);
		});
	});

	describe("PATCH /api/pins/:id (tagIds)", () => {
		test("attaches tag IDs to a pin", async () => {
			const pin = await (
				await request(h, "POST", "/api/pins", {
					latitude: 1,
					longitude: 2,
				})
			).json();
			const tagA = await createTag(h, "A");
			const tagB = await createTag(h, "B");

			const res = await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [tagA, tagB],
			});
			expect(res.status).toBe(200);
			const body = (await res.json()) as PinRow;
			expect(new Set(body.tagIds)).toEqual(new Set([tagA, tagB]));
		});

		test("replaces tags on subsequent updates", async () => {
			const pin = await (
				await request(h, "POST", "/api/pins", {
					latitude: 1,
					longitude: 2,
				})
			).json();
			const tagA = await createTag(h, "A");
			const tagB = await createTag(h, "B");
			await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [tagA],
			});
			const res = await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [tagB],
			});
			const body = (await res.json()) as PinRow;
			expect(body.tagIds).toEqual([tagB]);
		});

		test("clears tags when given empty list", async () => {
			const pin = await (
				await request(h, "POST", "/api/pins", {
					latitude: 1,
					longitude: 2,
				})
			).json();
			const tag = await createTag(h, "X");
			await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [tag],
			});
			const res = await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [],
			});
			expect(((await res.json()) as PinRow).tagIds).toEqual([]);
		});

		test("rejects tagIds belonging to other users (400 Invalid tagIds)", async () => {
			const pin = await (
				await request(h, "POST", "/api/pins", {
					latitude: 1,
					longitude: 2,
				})
			).json();
			h.asUser("u2");
			const otherTag = await createTag(h, "Other");
			h.asUser("u1");
			const res = await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [otherTag],
			});
			expect(res.status).toBe(400);
		});

		test("transaction rolls back when tagIds validation fails (pin keeps prior tags)", async () => {
			const pin = await (
				await request(h, "POST", "/api/pins", {
					latitude: 1,
					longitude: 2,
				})
			).json();
			const goodTag = await createTag(h, "Good");
			await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [goodTag],
			});

			h.asUser("u2");
			const otherTag = await createTag(h, "Other");
			h.asUser("u1");
			const bad = await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [otherTag],
			});
			expect(bad.status).toBe(400);

			const after = (await (await request(h, "GET", "/api/pins")).json()) as PinRow[];
			const updated = after.find((p) => p.id === pin.id);
			expect(updated?.tagIds).toEqual([goodTag]);
		});

		test("returns 404 when pin belongs to another user", async () => {
			h.asUser("u2");
			const otherPin = await (
				await request(h, "POST", "/api/pins", {
					latitude: 1,
					longitude: 2,
				})
			).json();
			h.asUser("u1");
			const res = await request(h, "PATCH", `/api/pins/${otherPin.id}`, {
				tagIds: [],
			});
			expect(res.status).toBe(404);
		});

		test("rejects invalid uuid", async () => {
			const res = await request(h, "PATCH", "/api/pins/not-a-uuid", {
				tagIds: [],
			});
			expect(res.status).toBe(400);
		});
	});

	describe("GET /api/pins", () => {
		test("returns pins with their tagIds joined", async () => {
			const pin = await (
				await request(h, "POST", "/api/pins", {
					latitude: 1,
					longitude: 2,
				})
			).json();
			const tag = await createTag(h, "T");
			await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [tag],
			});
			const body = (await (await request(h, "GET", "/api/pins")).json()) as PinRow[];
			expect(body.length).toBe(1);
			expect(body[0].tagIds).toEqual([tag]);
		});

		test("does not leak other users' pins", async () => {
			await request(h, "POST", "/api/pins", { latitude: 1, longitude: 2 });
			h.asUser("u2");
			await request(h, "POST", "/api/pins", { latitude: 3, longitude: 4 });
			const mine = (await (await request(h, "GET", "/api/pins")).json()) as PinRow[];
			expect(mine.length).toBe(1);
			expect(mine[0].latitude).toBe(3);
		});
	});

	describe("DELETE /api/pins/:id", () => {
		test("cascade-deletes pin_tags when pin is removed", async () => {
			const pin = await (
				await request(h, "POST", "/api/pins", {
					latitude: 1,
					longitude: 2,
				})
			).json();
			const tag = await createTag(h, "T");
			await request(h, "PATCH", `/api/pins/${pin.id}`, {
				tagIds: [tag],
			});
			const del = await request(h, "DELETE", `/api/pins/${pin.id}`);
			expect(del.status).toBe(204);

			// pin_tags row should be gone via FK cascade — verify by inserting
			// the tag onto a new pin successfully (no orphan rows interfering).
			const newPin = await (
				await request(h, "POST", "/api/pins", {
					latitude: 5,
					longitude: 6,
				})
			).json();
			const res = await request(h, "PATCH", `/api/pins/${newPin.id}`, {
				tagIds: [tag],
			});
			expect(res.status).toBe(200);
		});
	});
});
