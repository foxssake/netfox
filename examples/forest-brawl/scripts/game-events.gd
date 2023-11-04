extends Node
# Only used for Forest Brawl example

signal on_brawler_spawn(brawler: BrawlerController)
signal on_own_brawler_spawn(brawler: BrawlerController)
signal on_brawler_fall(brawler: BrawlerController)
signal on_brawler_respawn(brawler: BrawlerController)
signal on_brawler_despawn(brawler: BrawlerController)

signal on_scores_updated(scores: Dictionary)
