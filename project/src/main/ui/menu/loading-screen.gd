extends Control
"""
Shows a progress bar while resources are loading.
"""

func _ready() -> void:
	Global.benchmark_start("initial-load")
	ResourceCache.connect("finished_loading", self, "_on_ResourceCache_finished_loading")
	ResourceCache.start_load()


func _process(_delta: float) -> void:
	$ProgressBar.value = 100.0 * ResourceCache.get_progress()


func _on_ResourceCache_finished_loading() -> void:
	Global.benchmark_end("initial-load")
	Breadcrumb.push_trail("res://src/main/ui/menu/SplashScreen.tscn")
