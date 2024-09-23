const express = require('express');
const cors = require('cors');
const { verifyTelegramWebAppData } = require('./tg');
const { ethers, } = require('ethers');
const { v4: uuidV4 } = require('uuid');
const path = require('path');


const app = express();
const port = 3010;

let usersToPrivateKeys = {}
let posts = {}

app.use(express.json());
app.use(cors());

app.get("/wallet", async (req, res) => {
    const { query } = req;
    const { is_valid, user } = verifyTelegramWebAppData(query);
    if (!is_valid || !user) {
        return res.status(400).send({
            success: false,
            error: "Invalid request"
        });
    }
    if (!usersToPrivateKeys[user.id]) {
        usersToPrivateKeys[user.id] = ethers.Wallet.createRandom().privateKey;
    }
    const wallet = new ethers.Wallet(usersToPrivateKeys[user.id]);
    res.send({
        address: wallet.address,
        privateKey: wallet.privateKey
    });
});

app.post("/post", async (req, res) => {
    const { query } = req;
    const { is_valid, user } = verifyTelegramWebAppData(query);
    if (!is_valid || !user) {
        return res.status(400).send({
            success: false,
            error: "Invalid request"
        });
    }
    const postId = uuidV4();
    posts[postId] = {
        title: req.body.title,
        content: req.body.content,
        author: user.id
    };
    res.send({success: true, postId});
});


app.get("/posts/:id", async (req, res) => {
    const { query } = req;
    const { is_valid, user } = verifyTelegramWebAppData(query);
    if (!is_valid || !user) {
        return res.status(400).send({
            success: false,
            error: "Invalid request"
        });
    }
    const id = req.params.id;
    const post = posts[id];
    if (!post) {
        return res.status(404).send({
            success: false,
            error: "Post not found"
        });
    }
    res.send(post);
});

///// Static Pages

app.get("/", (req, res) => {
    res.sendFile(path.join(__dirname, "../frontend/index.html"));
});

app.get("/post", (req, res) => {
    res.sendFile(path.join(__dirname, "../frontend/post.html"));
});

app.listen(port, () => {
    console.log(`Server is running on port ${port}`);
});