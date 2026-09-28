import * as v from "valibot";

export const ColorHexSchema = v.pipe(v.string(), v.regex(/^#[0-9a-fA-F]{6}$/));

export const TagNameSchema = v.pipe(
	v.string(),
	v.minLength(1),
	v.maxLength(50),
);

export const CreateTagSchema = v.object({
	mapId: v.optional(v.pipe(v.string(), v.uuid())),
	name: TagNameSchema,
	color: ColorHexSchema,
});

export const UpdateTagSchema = v.object({
	name: v.optional(TagNameSchema),
	color: v.optional(ColorHexSchema),
});

export const TagSchema = v.object({
	id: v.string(),
	userId: v.string(),
	mapId: v.optional(v.string()),
	name: v.string(),
	color: v.string(),
	createdAt: v.string(),
});

export const TagsArraySchema = v.array(TagSchema);

export const GetTagsQuerySchema = v.object({
	mapId: v.optional(v.pipe(v.string(), v.uuid())),
});

export const UpdatePinSchema = v.object({
	tagIds: v.optional(v.array(v.string())),
});
