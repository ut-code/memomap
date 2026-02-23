const url = process.argv[2];
if (!url) {
  console.error("Usage: bun scripts/update-db-url.ts <prisma+postgres://...>");
  process.exit(1);
}

let dbUrl = url;
if (url.startsWith("prisma+postgres://")) {
  const apiKey = new URL(url.replace("prisma+postgres", "https")).searchParams.get("api_key");
  if (!apiKey) {
    console.error("api_key not found in URL");
    process.exit(1);
  }
  const base64 = apiKey.replace(/-/g, "+").replace(/_/g, "/");
  const decoded = JSON.parse(atob(base64));
  dbUrl = decoded.databaseUrl;
}

const devVarsPath = ".dev.vars";
let content = "";
try {
  content = await Bun.file(devVarsPath).text();
} catch {
  // file doesn't exist
}

if (content.includes("DATABASE_URL=")) {
  content = content.replace(/DATABASE_URL=.*\n?/, `DATABASE_URL="${dbUrl}"\n`);
} else {
  content = `DATABASE_URL="${dbUrl}"\n` + content;
}

await Bun.write(devVarsPath, content);
console.log("Updated .dev.vars with DATABASE_URL:", dbUrl);
