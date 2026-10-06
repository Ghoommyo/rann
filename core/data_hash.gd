## A fingerprint of all gameplay data: every character, move, fight style and rule.
##
## 💡 Online, both players run their own copy of the simulation. If one of
## them has different numbers (an older balance patch, a modded file), the two
## simulations would slowly disagree: a desync. Comparing this hash before a
## match catches that up front, with a clear message instead of a broken fight.
##
## Only gameplay data counts. Models, animations, colors and portraits don't
## affect the simulation, so changing them doesn't change the hash.
class_name DataHash

## Properties that don't affect gameplay.
const IGNORED := ["script", "resource_path", "resource_name", "resource_local_to_scene",
	"resource_scene_unique_id", "model_scene", "animation_library", "model_scale", "portrait",
	"color", "description", "display_name", "animation_name"]


## Hash of every character in the registry plus the Rules constants.
static func compute() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	var rules: Dictionary = load("res://core/rules.gd").get_script_constant_map()
	var names := rules.keys()
	names.sort()
	for constant in names:
		_feed_text(ctx, "%s=%s;" % [constant, var_to_str(rules[constant])])
	for def in CharacterRegistry.all():
		_feed_object(ctx, def)
	return ctx.finish().hex_encode()


static func _feed_object(ctx: HashingContext, obj: Object) -> void:
	_feed_text(ctx, "{%s:" % obj.get_class())
	if obj.get_script():
		_feed_text(ctx, (obj.get_script() as Script).resource_path)
	for prop in obj.get_property_list():
		if not (prop.usage & PROPERTY_USAGE_STORAGE) or prop.name in IGNORED:
			continue
		_feed_text(ctx, prop.name + "=")
		_feed_value(ctx, obj.get(prop.name))
	_feed_text(ctx, "}")


static func _feed_value(ctx: HashingContext, value: Variant) -> void:
	if value is Resource:
		_feed_object(ctx, value)
	elif value is Array:
		_feed_text(ctx, "[")
		for item in value:
			_feed_value(ctx, item)
		_feed_text(ctx, "]")
	else:
		_feed_text(ctx, var_to_str(value) + ";")


static func _feed_text(ctx: HashingContext, text: String) -> void:
	ctx.update(text.to_utf8_buffer())
