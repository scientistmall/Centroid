class_name StoryParser
extends RefCounted
## Parses the plain-text `.story` scene format into a list of steps.
##
## Format, one command per line:
##   # comment
##   @card Line one | Line two | Line three    title card on black (day / place)
##   @title BIG HEADING | optional subtitle    large dramatic heading
##   @bg backdrop_id                            change background
##   @show left|right character_id             place a portrait
##   @hide left|right|all                       remove portrait(s)
##   @flashback on|off                          memory tint on/off
##   @flag flag_name                            set a story flag
##   @wait 1.5                                  pause (seconds)
##   @next story|fight|menu id                  where to go when the scene ends
##   NAME: spoken line                          dialogue (NAME in capitals)
##   NAME [angry]: spoken line                  dialogue with an expression
##                                              (neutral, angry, determined, sad, shocked, smile)
##   > narration text                           stage direction / narration

const CHARACTERS_PATH := "res://data/characters.json"

static var _characters: Dictionary = {}


static func characters() -> Dictionary:
	if _characters.is_empty():
		var f := FileAccess.open(CHARACTERS_PATH, FileAccess.READ)
		if f:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_characters = d
	return _characters


static func character(id: String) -> Dictionary:
	return characters().get(id, {"name": id.to_upper(), "color": "#cccccc", "hair": "short"})


static func id_for_name(display_name: String) -> String:
	var upper := display_name.strip_edges().to_upper()
	var chars := characters()
	for id in chars:
		if String(chars[id].get("name", "")).to_upper() == upper:
			return id
	return upper.to_lower().replace(" ", "_")


static func load_file(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Story file not found: %s" % path)
		return {"steps": [], "next": {"type": "menu"}}
	return parse(f.get_as_text())


static func parse(text: String) -> Dictionary:
	var steps: Array = []
	var next := {"type": "menu"}
	var line_no := 0
	for raw in text.split("\n"):
		line_no += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("@"):
			var sp := line.find(" ")
			var cmd := (line.substr(1) if sp == -1 else line.substr(1, sp - 1)).to_lower()
			var arg := "" if sp == -1 else line.substr(sp + 1).strip_edges()
			match cmd:
				"card", "title":
					var parts: Array = []
					for p in arg.split("|"):
						parts.append(p.strip_edges())
					steps.append({"t": cmd, "lines": parts})
				"bg":
					steps.append({"t": "bg", "id": arg})
				"show":
					var a := arg.split(" ", false)
					if a.size() >= 2:
						steps.append({"t": "show", "slot": a[0], "who": a[1]})
				"hide":
					steps.append({"t": "hide", "slot": arg if arg != "" else "all"})
				"flashback":
					steps.append({"t": "flashback", "on": arg.to_lower() == "on"})
				"flag":
					steps.append({"t": "flag", "name": arg})
				"wait":
					steps.append({"t": "wait", "sec": float(arg)})
				"next":
					var n := arg.split(" ", false)
					next = {"type": n[0] if n.size() > 0 else "menu"}
					if n.size() > 1:
						next["id"] = n[1]
				_:
					push_warning("Story line %d: unknown command @%s" % [line_no, cmd])
		elif line.begins_with(">"):
			steps.append({"t": "narrate", "text": line.substr(1).strip_edges()})
		else:
			var colon := line.find(":")
			var who := line.substr(0, colon) if colon > 0 else ""
			# optional expression: "KAEL [angry]: text"
			var expr := ""
			var lb := who.find("[")
			if lb != -1 and who.find("]") > lb:
				expr = who.substr(lb + 1, who.find("]") - lb - 1).strip_edges().to_lower()
				who = who.substr(0, lb)
			if colon > 0 and who.strip_edges() == who.strip_edges().to_upper() and who.length() <= 24:
				steps.append({
					"t": "line",
					"who": id_for_name(who),
					"name": who.strip_edges(),
					"text": line.substr(colon + 1).strip_edges(),
					"expr": expr,
				})
			else:
				steps.append({"t": "narrate", "text": line})
	return {"steps": steps, "next": next}
