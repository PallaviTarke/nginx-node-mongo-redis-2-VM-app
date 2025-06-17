const express = require("express");
const mongoose = require("mongoose");
const path = require("path");
const { createClient } = require("redis");
const client = require('prom-client');

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const mongoUrl = process.env.MONGO_URL || "mongodb://mongo:27017/mydb";
const redisUrl = process.env.REDIS_URL || "redis://redis:6379";

mongoose.connect(mongoUrl, { useNewUrlParser: true, useUnifiedTopology: true })
    .then(() => console.log("MongoDB connected"))
    .catch(err => console.error("MongoDB connection error:", err));

const redis = createClient({ url: redisUrl });
redis.connect().then(() => console.log("Redis connected"))
    .catch(err => console.error("Redis connection error:", err));

const User = mongoose.model("User", new mongoose.Schema({ name: String }));

// Prometheus metrics
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics();

const httpRequestCounter = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
});

app.use((req, res, next) => {
    httpRequestCounter.inc();
    next();
});

app.post("/add", async (req, res) => {
    try {
        const name = req.body.name;
        const user = new User({ name });
        await user.save();
        await redis.set("lastUser", name);
        res.json({ success: true, user: name });
    } catch (err) {
        console.error("Error in /add:", err);
        res.status(500).json({ success: false, error: err.message });
    }
});

app.get("/recent", async (req, res) => {
    try {
        const lastUser = await redis.get("lastUser");
        res.json({ recentUser: lastUser });
    } catch (err) {
        console.error("Error in /recent:", err);
        res.status(500).json({ error: err.message });
    }
});

app.get("/all", async (req, res) => {
    try {
        const users = await User.find();
        res.json(users);
    } catch (err) {
        console.error("Error in /all:", err);
        res.status(500).json({ error: err.message });
    }
});

app.get("/health", (req, res) => {
    res.status(200).send("OK");
});

app.get('/metrics', async (req, res) => {
    res.set('Content-Type', client.register.contentType);
    res.end(await client.register.metrics());
});

app.listen(3000, () => console.log("Server running on 3000"));
