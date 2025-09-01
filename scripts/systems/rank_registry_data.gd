class_name RankRegistryData
extends Resource

@export var ranks: Dictionary = {}

func _init() -> void:
    pass

func add_rank(rank_name: String, rank_resource: Resource) -> void:
    ranks[rank_name] = rank_resource

func get_rank(rank_name: String) -> Resource:
    return ranks.get(rank_name)

func get_all_ranks() -> Dictionary:
    return ranks.duplicate()

func get_rank_by_points(points: int) -> Resource:
    var closest_rank: Resource = null
    var closest_diff: int = 999999
    
    for rank_name in ranks:
        var rank: Resource = ranks[rank_name]
        if rank.has_method("get_points_required"):
            var rank_points: int = rank.get_points_required()
            var diff: int = abs(points - rank_points)
            if diff < closest_diff:
                closest_diff = diff
                closest_rank = rank
    
    return closest_rank

func get_next_rank(current_rank_name: String) -> Resource:
    var rank_list: Array = []
    
    for rank_name in ranks:
        var rank: Resource = ranks[rank_name]
        if rank.has_method("get_points_required"):
            rank_list.append({"name": rank_name, "points": rank.get_points_required(), "resource": rank})
    
    rank_list.sort_custom(_sort_ranks_by_points)
    
    var current_index: int = -1
    for i in range(rank_list.size()):
        if rank_list[i]["name"] == current_rank_name:
            current_index = i
            break
    
    if current_index != -1 and current_index + 1 < rank_list.size():
        return rank_list[current_index + 1]["resource"]
    
    return null

func _sort_ranks_by_points(a: Dictionary, b: Dictionary) -> bool:
    return a["points"] < b["points"]