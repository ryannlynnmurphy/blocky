# Attach once, call make_atlas_material() for the chunk mesh.
# The three settings that matter for pixel art: nearest filter, no mipmap
# blur across tile seams, and vertex colours ON so the mesher can tint biomes.
class_name PixelMaterial
extends RefCounted


static func make_atlas_material(atlas: Texture2D) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = atlas
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.metallic = 0.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

static func make_cutout_material(tex: Texture2D) -> StandardMaterial3D:
	# leaves and grass cards: cutout, never alpha blend
	var m := make_atlas_material(tex)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m
