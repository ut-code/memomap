import { afterEach, beforeEach, describe, expect, test } from "bun:test";
import { createTestHarness, request, seedUser, type TestHarness } from "./helpers";

type MapRow = {
	id: string;
	userId: string;
	name: string;
	description: string | null;
	createdAt: string;
};

describe("maps API", () => {
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

	test("POST creates a map", async () => {
		const res = await request(h, "POST", "/api/maps", {
			name: "My Map",
			description: "desc",
		});
		expect(res.status).toBe(201);
		const body = (await res.json()) as MapRow;
		expect(body.name).toBe("My Map");
		expect(body.description).toBe("desc");
	});

	test("POST allows duplicate map names per user (no unique constraint)", async () => {
		const r1 = await request(h, "POST", "/api/maps", { name: "Same" });
		const r2 = await request(h, "POST", "/api/maps", { name: "Same" });
		expect(r1.status).toBe(201);
		expect(r2.status).toBe(201);
		const list = (await (await request(h, "GET", "/api/maps")).json()) as MapRow[];
		expect(list.length).toBe(2);
	});

	test("PUT updates name", async () => {
		const m = await (
			await request(h, "POST", "/api/maps", { name: "Old" })
		).json();
		const res = await request(h, "PUT", `/api/maps/${m.id}`, { name: "New" });
		expect(res.status).toBe(200);
		expect(((await res.json()) as MapRow).name).toBe("New");
	});

	test("PUT returns 404 for another user's map", async () => {
		h.asUser("u2");
		const other = await (
			await request(h, "POST", "/api/maps", { name: "Other" })
		).json();
		h.asUser("u1");
		const res = await request(h, "PUT", `/api/maps/${other.id}`, {
			name: "Hack",
		});
		expect(res.status).toBe(404);
	});

	test("PUT rejects invalid uuid", async () => {
		const res = await request(h, "PUT", "/api/maps/not-a-uuid", {
			name: "X",
		});
		expect(res.status).toBe(400);
	});

	test("DELETE cascades to pins and drawings", async () => {
		const m = await (
			await request(h, "POST", "/api/maps", { name: "M" })
		).json();
		await request(h, "POST", "/api/pins", {
			latitude: 1,
			longitude: 2,
			mapId: m.id,
		});
		await request(h, "POST", "/api/drawings", {
			mapId: m.id,
			points: [{ x: 0, y: 0 }],
			color: "#000000",
			strokeWidth: 1,
		});

		const del = await request(h, "DELETE", `/api/maps/${m.id}`);
		expect(del.status).toBe(204);

		const pinsList = await (await request(h, "GET", "/api/pins")).json();
		const drawingsList = await (await request(h, "GET", "/api/drawings")).json();
		expect(pinsList).toEqual([]);
		expect(drawingsList).toEqual([]);
	});

	test("GET only returns the current user's maps", async () => {
		await request(h, "POST", "/api/maps", { name: "Mine" });
		h.asUser("u2");
		await request(h, "POST", "/api/maps", { name: "Other" });
		h.asUser("u1");
		const list = (await (await request(h, "GET", "/api/maps")).json()) as MapRow[];
		expect(list.length).toBe(1);
		expect(list[0].name).toBe("Mine");
	});
});
