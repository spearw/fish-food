## pack_list.gd  (class: DeckList)
## A Resource holding the master list of selectable Decks in the game.
## (Formerly "PackList" -- the file keeps its legacy name; the class is "DeckList".)
class_name DeckList
extends Resource

@export var decks: Array[Deck]
