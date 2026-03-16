import * as v from "valibot";

export const CreateMapSchema = v.object({
	name: v.pipe(v.string(), v.minLength(1), v.maxLength(100)),
	description: v.optional(v.nullable(v.pipe(v.string(), v.maxLength(500)))),
});

export const UpdateMapSchema = v.object({
	name: v.optional(v.pipe(v.string(), v.minLength(1), v.maxLength(100))),
	description: v.optional(v.nullable(v.pipe(v.string(), v.maxLength(500)))),
});

export const MapSchema = v.object({
	id: v.string(),
	userId: v.string(),
	name: v.string(),
	description: v.nullable(v.string()),
	createdAt: v.string(),
});

export const MapsArraySchema = v.array(MapSchema);
