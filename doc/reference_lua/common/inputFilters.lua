-- This Source Code Form is subject to the terms of the bCDDL, v. 1.1.
-- If a copy of the bCDDL was not distributed with this
-- file, You can obtain one at http://beamng.com/bCDDL-1.1.txt

-- Input filters
-- A filter value of -1 can be used by C++ side: it's automatically guessed/translated into a >=0 filter and then sent to lua side. See S8 getFilterType(...) C++ function
FILTER_KBD    = 0
FILTER_PAD    = 1
FILTER_DIRECT = 2
FILTER_KBD2   = 3
FILTER_AI     = "FILTER_AI"

FILTER_NAME = {
  [FILTER_KBD] = "Keyboard",
  [FILTER_PAD] = "Gamepad",
  [FILTER_DIRECT] = "Direct",
  [FILTER_KBD2] = "KeyboardDrift"
}
