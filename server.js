const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static('frontend'));

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('MongoDB Connected...'))
  .catch(err => console.log('MongoDB Connection Error:', err));

// Bet Schema
const betSchema = new mongoose.Schema({
  player: String,
  amount: Number,
  betType: String,
  result: Number,
  win: Boolean,
  timestamp: { type: Date, default: Date.now }
});

const Bet = mongoose.model('Bet', betSchema);

// API Routes
app.post('/api/bets', async (req, res) => {
  try {
    const bet = new Bet(req.body);
    await bet.save();
    res.status(201).json(bet);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Serve frontend
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'frontend', 'index.html'));
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));