extends "res://addons/gut/test.gd"
"""
Unit test for name utils functions.
"""

func test_sanitize_name_length() -> void:
	# 31 character limit
	assert_eq(NameUtils.sanitize_name(""), "X")
	assert_eq(NameUtils.sanitize_name("A"), "A")
	assert_eq(NameUtils.sanitize_name(
			"0123456789012345678901234567890123456789"
			+ "0123456789012345678901234567890123456789"),
			"012345678901234567890123456789012345678901234567890123456789012")


func test_sanitize_name_first_and_last_character() -> void:
	# don't start or end the filename with whitespace or punctuation
	assert_eq(NameUtils.sanitize_name(" spoil633"), "spoil633")
	assert_eq(NameUtils.sanitize_name(".spoil633"), "spoil633")
	assert_eq(NameUtils.sanitize_name("-spoil633"), "spoil633")
	assert_eq(NameUtils.sanitize_name("?spoil633"), "spoil633")
	
	assert_eq(NameUtils.sanitize_name("spoil633 "), "spoil633")
	assert_eq(NameUtils.sanitize_name("spoil633."), "spoil633")
	assert_eq(NameUtils.sanitize_name("spoil633-"), "spoil633")
	assert_eq(NameUtils.sanitize_name("spoil633?"), "spoil633")


func test_sanitize_name_invalid_characters() -> void:
	assert_eq(NameUtils.sanitize_name("abc	def"), "abc def")


func test_sanitize_name_valid_characters() -> void:
	assert_eq(NameUtils.sanitize_name("Spoil633"), "Spoil633")
	assert_eq(NameUtils.sanitize_name("spoil-633"), "spoil-633")
	assert_eq(NameUtils.sanitize_name("húsbóndi"), "húsbóndi")
	assert_eq(NameUtils.sanitize_name("Dr. Smiles"), "Dr. Smiles")


func test_sanitize_short_name() -> void:
	# multiple words; pick the longest word
	assert_eq(NameUtils.sanitize_short_name("Crowd Nosy Distance Embarrass"), "Embarrass")
	assert_eq(NameUtils.sanitize_short_name("Crowd Embarrass Nosy Distance"), "Embarrass")
	
	# one huge word; truncate it near a vowel
	assert_eq(NameUtils.sanitize_short_name("Crowdembarrassnosydistance"), "Crow")
	assert_eq(NameUtils.sanitize_short_name("Crodwembarrassnosydistance"), "Croddy")
	
	# one huge mess of consonants
	assert_eq(NameUtils.sanitize_short_name("Crwdmbrrssnsydstncbrshcvr"), "Crwdm")
