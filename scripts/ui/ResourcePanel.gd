extends Control

@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var total_label: Label = $PanelContainer/MarginContainer/VBoxContainer/TotalLabel

func _ready() -> void:
	title_label.text = "CoinBar"
	_hide_optional_legacy_labels()
	ResourceManager.coins_changed.connect(_on_coins_changed)
	_refresh_coins(ResourceManager.get_coins())

func _on_coins_changed(_before_amount: int, after_amount: int, _delta_amount: int) -> void:
	_refresh_coins(after_amount)

func _refresh_coins(amount: int) -> void:
	total_label.text = "Coins: %d" % amount

func _hide_optional_legacy_labels() -> void:
	for node_name in ["LastChangeLabel", "BeforeAfterLabel"]:
		var node: Node = $PanelContainer/MarginContainer/VBoxContainer.get_node_or_null(node_name)
		if node is CanvasItem:
			(node as CanvasItem).visible = false
