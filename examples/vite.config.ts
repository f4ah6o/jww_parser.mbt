import { defineConfig } from "vite";

export default defineConfig({
  base: "/jww_parser.mbt/",
  build: {
    outDir: "dist",
    sourcemap: true,
  },
  optimizeDeps: {
    exclude: ["@f12o/three-dxf"],
  },
  server: {
    port: 5173,
  },
});
