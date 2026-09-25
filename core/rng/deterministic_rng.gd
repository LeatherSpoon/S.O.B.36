extends Reference
# Park-Miller minimal standard. Explicit integer math; state fits JSON exactly.
const MODULUS = 2147483647
const MULTIPLIER = 16807
const ALGORITHM = "park_miller_16807_v1"
var state = 1

func _init(seed_value = 1):
	assert(seed_value >= 1 and seed_value < MODULUS)
	state = int(seed_value)

func next_int():
	state = (state * MULTIPLIER) % MODULUS
	return state

func roll(sides):
	assert(sides > 0 and sides < MODULUS)
	# Rejection sampling avoids modulo bias.
	var limit = (MODULUS - 1) - ((MODULUS - 1) % sides)
	var value = next_int() - 1
	while value >= limit:
		value = next_int() - 1
	return value % sides + 1

func to_data():
	return {"algorithm": ALGORITHM, "state": state}
