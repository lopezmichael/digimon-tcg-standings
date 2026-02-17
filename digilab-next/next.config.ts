import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // duckdb is a native addon that cannot be bundled
  serverExternalPackages: ['duckdb'],
};

export default nextConfig;
