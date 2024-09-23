import express from "express";
import { $ } from "zx";

const app = express();
const PORT = parseInt(process.env.PORT) || 3000;

app.use(express.static("public"));

app.get("/run", async (req, res) => {
  try {
    const code = String(req.query.code);
    if(/^[\x20-\x7E\r\n]*$/.test(code) === false)
      throw new Error("Invalid characters");
    const commands = code.toLowerCase().match(/![a-z]+/g);
    if (commands !== null && (commands.includes("!exec") || commands.includes("!e")))
      throw new Error("!exec is not allowed");
    const uuid = crypto.randomUUID();
    await $({
      cwd: "public/out",
      timeout: "3s",
      input: code,
    })`chisel --no-vm > ${uuid}`;
    res.send({ uuid });
  } catch(e) {
    console.log(e)
    res.status(500).send("error");
  }
});

app.listen(PORT);
