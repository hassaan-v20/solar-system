import { defineConfig } from "vite";

// host:true exposes the dev server on the LAN so a second machine can test quickly.
export default defineConfig({
  server: { host: true },
});
