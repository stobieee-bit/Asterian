## StationSpawner — Spawns all processing stations from DataManager
##
## Reads processing_stations from DataManager and places them in the world.
## Each station is a clickable StaticBody3D on collision layer 32 (layer 6).
extends Node3D

var station_script: GDScript = preload("res://scripts/world/processing_station.gd")

func _ready() -> void:
	_spawn_all_stations()

func _spawn_all_stations() -> void:
	var count: int = 0
	for station_data in DataManager.processing_stations:
		var station_id: String = str(station_data.get("id", "station_%d" % count))

		var station: StaticBody3D = StaticBody3D.new()
		station.name = "Station_%s" % station_id
		station.set_script(station_script)
		add_child(station)
		station.setup(station_data)
		count += 1

	print("StationSpawner: %d processing stations spawned" % count)
