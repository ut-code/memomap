const content = await Bun.file(".dev.vars").text();
const match = content.match(/DATABASE_URL=["']?(.+?)["']?\n/);
if (!match) {
  console.error("DATABASE_URL not found in .dev.vars");
  process.exit(1);
}

Bun.spawnSync(["bunx", "drizzle-kit", "push"], {
  stdio: ["inherit", "inherit", "inherit"],
  env: { ...process.env, DATABASE_URL: match[1] },
});
