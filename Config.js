module.exports = {
  buildbear: {
-    url: process.env.BUILDBEAR_RPC_URL
+    url: process.env.BUILDBEAR_RPC_URL || "https://rpc.buildbear.io/curly-sandman-10c6e11a"
  }
}
