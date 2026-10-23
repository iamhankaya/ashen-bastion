class_name Choice
extends RefCounted
## Seviye atlama kartı.

const KIND_UPGRADE := &"upgrade"
const KIND_NEW := &"new"
const KIND_EVOLUTION := &"evolution"
const KIND_HEAL := &"heal"

var kind: StringName = KIND_UPGRADE
var skill_id: StringName = &""
var from_level: int = 0
var to_level: int = 0
var title: String = ""
var desc: String = ""
var icon: String = ""
