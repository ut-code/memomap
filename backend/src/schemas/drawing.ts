import * as v from "valibot";

export const PointSchema = v.object({
	lat: v.number(),
	lng: v.number(),
});

export const CreateDrawingSchema = v.object({
	points: v.array(PointSchema),
	color: v.string(),
	strokeWidth: v.pipe(v.number(), v.minValue(0.1), v.maxValue(50)),
	mapId: v.optional(v.nullable(v.string())),
});

export const BatchCreateDrawingsSchema = v.object({
	drawings: v.pipe(
		v.array(
			v.object({
				points: v.array(PointSchema),
				color: v.string(),
				strokeWidth: v.pipe(v.number(), v.minValue(0.1), v.maxValue(50)),
				mapId: v.optional(v.nullable(v.string())),
			}),
		),
		v.maxLength(100),
	),
});

export const DrawingSchema = v.object({
	id: v.string(),
	userId: v.string(),
	mapId: v.nullable(v.string()),
	points: v.array(PointSchema),
	color: v.string(),
	strokeWidth: v.number(),
	createdAt: v.string(),
});

export const DrawingsArraySchema = v.array(DrawingSchema);
