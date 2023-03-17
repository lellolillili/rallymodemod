local newdecoder = require 'libs/lunajson/lunajson.decoder'
local newencoder = require 'libs/lunajson/lunajson.encoder'
local sax = require 'libs/lunajson/lunajson.sax'
-- If you need multiple contexts of decoder and/or encoder,
-- you can require lunajson.decoder and/or lunajson.encoder directly.
return {
  decode = newdecoder(),
  encode = newencoder(),
  newparser = sax.newparser,
  newfileparser = sax.newfileparser,
}
