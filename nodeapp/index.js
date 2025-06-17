const express = require("express");
const mongoose = require("mongoose");
const path = require("path");
const { createClient } = require("redis");

const app = express();
app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const mongoUrl = process.env.MONGO_URL || "mongodb://mongo:27017/mydb";
const redisUrl = process.env.REDIS_URL || "redis://redis:6379";

mongoose.connect(mongoUrl).then(() => console.log("MongoDB connected"));
const redis = createClient({ url: redisUrl });
redis.connect().then(() => console.log("Redis connected"));

const User = mongoose.model("User", new mongoose.Schema({ name: String }));

app.post("/add", async (req, res) => {
  const name = req.body.name;
  const user = new User({ name });
  await user.save();
  await redis.set("lastUser", name);
  res.json({ success: true, user: name });
});

app.get("/recent", async (req, res) => {
  const lastUser = await redis.get("lastUser");
  res.json({ recentUser: lastUser });
});

app.get("/all", async (req, res) => {
  const users = await User.find();
  res.json(users);
});

app.listen(3000, () => console.log("Server running on 3000"));

const client = require('prom-client');
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

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
