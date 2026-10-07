class_name EnemyRoleDefinition
extends Resource
## Reusable role logic (GDD: "Reuse role logic extensively").
##
## Default considerations are merged into every action that expresses this role (the action's
## role_tags, or the enemy's role when the action has none), filtered by intent category.

@export var role: Enums.EnemyRole = Enums.EnemyRole.RAVAGER
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var default_considerations: Array[AIConsiderationDefinition] = []


func validate() -> PackedStringArray:
	var problems := PackedStringArray()
	for consideration in default_considerations:
		if consideration == null:
			problems.append("role %s has a null consideration" % display_name)
		else:
			problems.append_array(consideration.validate())
	return problems
