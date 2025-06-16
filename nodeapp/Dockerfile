<!DOCTYPE html>
<html>
<head>
  <title>Fullstack Demo</title>
</head>
<body>
  <h1>User Entry Form</h1>
  <input type="text" id="name" placeholder="Enter name" />
  <button onclick="addUser()">Add</button>
  <p id="recent"></p>
  <script>
    async function addUser() {
      const name = document.getElementById("name").value;
      await fetch("/add", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ name })
      });
      const res = await fetch("/recent");
      const data = await res.json();
      document.getElementById("recent").innerText = `Recent: ${data.recentUser}`;
    }
  </script>
</body>
</html>