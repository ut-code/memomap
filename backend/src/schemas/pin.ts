import * as v from "valibot";

export const LatitudeSchema = v.pipe(
	v.number(),
	v.minValue(-90),
	v.maxValue(90),
);

export const LongitudeSchema = v.pipe(
	v.number(),
	v.minValue(-180),
	v.maxValue(180),
);

export const CreatePinSchema = v.object({
	latitude: LatitudeSchema,
	longitude: LongitudeSchema,
	mapId: v.optional(v.nullable(v.string())),
});

export const BatchCreatePinsSchema = v.object({
	pins: v.pipe(
		v.array(
			v.object({
				latitude: LatitudeSchema,
				longitude: LongitudeSchema,
				mapId: v.optional(v.nullable(v.string())),
			}),
		),
		v.maxLength(100),
	),
});

export const PinSchema = v.object({
	id: v.string(),
	userId: v.string(),
	mapId: v.nullable(v.string()),
	latitude: v.number(),
	longitude: v.number(),
	createdAt: v.string(),
});

export const PinsArraySchema = v.array(PinSchema);

export const UserSchema = v.object({
	userId: v.string(),
	email: v.string(),
});

export const ErrorSchema = v.object({
	error: v.string(),
});

export const HealthSchema = v.object({
	status: v.string(),
	timestamp: v.string(),
});
