const mongoose = require('mongoose');

const BetSchema = new mongoose.Schema({
  player: {
    type: String,
    required: true
  },
  amount: {
    type: Number,
    required: true
  },
  betType: {
    type: String,
    required: true
  },
  result: {
    type: Number,
    required: true
  },
  win: {
    type: Boolean,
    required: true
  },
  timestamp: {
    type: Date,
    default: Date.now
  }
});

module.exports = mongoose.model('Bet', BetSchema);