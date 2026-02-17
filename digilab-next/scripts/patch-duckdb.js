/**
 * Patch duckdb package.json to remove napi_versions field.
 *
 * Next.js 16 Turbopack panics when scanning duckdb's package.json
 * because the "binary" field is missing "napi_versions". However,
 * if napi_versions IS present, node-pre-gyp requires module_path
 * to contain {napi_build_version} substitution, which duckdb doesn't.
 *
 * The safest fix: ensure napi_versions is NOT in the binary field.
 * This allows both dev server and (once Turbopack is fixed) builds to work.
 */
const fs = require('fs');
const path = require('path');

const pkgPath = path.join(__dirname, '..', 'node_modules', 'duckdb', 'package.json');

try {
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  if (pkg.binary && pkg.binary.napi_versions) {
    delete pkg.binary.napi_versions;
    fs.writeFileSync(pkgPath, JSON.stringify(pkg, null, 2) + '\n');
    console.log('Patched duckdb: removed napi_versions from binary config');
  }
} catch (e) {
  // duckdb not installed yet, skip
}
