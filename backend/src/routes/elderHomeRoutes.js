const express = require("express");

const {
  createElderHome,
  getElderHomes,
} = require("../controllers/elderHomeController");

const router = express.Router();

router.post("/", createElderHome);
router.get("/", getElderHomes);

module.exports = router;