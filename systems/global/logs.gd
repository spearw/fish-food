## log.gd
## A global Singleton for storing a history of important game events.
extends Node

var message_history: Array[String] = []

# Console echo is opt-in (--verbose): one print() costs ~8ms on a Windows console, so routine
# logging was dropping frames -- the level-up screen's 4 log lines alone froze the game ~40ms.
# History always records regardless; the F3 log and crash dumps read from there.
var echo_to_console: bool = OS.is_stdout_verbose()

## Adds a new message to the log history.
func add_message(message):
	if typeof(message) == TYPE_ARRAY:
		# Convert each element to a string and join them with a space.
		message = " ".join(message.map(func(arg): return str(arg)))
	else:
		message = str(message)

	# Add time and timestamp in ms
	var time_str = Time.get_time_string_from_system()
	message_history.append("[%s] %s (%s)" % [time_str, message, Time.get_unix_time_from_system() * 1000])

	if echo_to_console:
		print(message)

## Returns the entire log history as a single string, formatted for a text file.
func get_history_as_string() -> String:
	return "\n".join(message_history)
