import { execSync } from 'child_process';
import { writeFileSync } from 'fs';
import path from 'path';

interface GeneratorContext {
  language: string;
  packageManager: string;
  frontendFramework: string | null;
  backendFramework: string | null;
}

function installCmd(pkgManager: string): string {
  switch (pkgManager) {
    case 'yarn': return 'yarn add -D';
    case 'pnpm': return 'pnpm add -D';
    default: return 'npm install -D';
  }
}

export async function generateEslint(root: string, context: GeneratorContext): Promise<void> {
  const { language, packageManager, frontendFramework } = context;

  // Python uses Ruff instead of ESLint
  if (language === 'python') {
    const ruffConfig = `[tool.ruff]
line-length = 120
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "W", "I", "N", "UP", "S", "B", "A", "C4", "DTZ", "ISC", "PIE", "RSE", "RET", "SLF", "SIM", "TCH", "ARG", "PTH"]
ignore = ["S101"]

[tool.ruff.lint.per-file-ignores]
"tests/**" = ["S101", "ARG"]
`;
    writeFileSync(path.join(root, 'ruff.toml'), ruffConfig, 'utf-8');
    return;
  }

  // Go uses golangci-lint
  if (language === 'go') {
    const golangciConfig = `linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
    - bodyclose
    - contextcheck
    - gosec
    - prealloc

linters-settings:
  gosec:
    excludes:
      - G104
`;
    writeFileSync(path.join(root, '.golangci.yml'), golangciConfig, 'utf-8');
    return;
  }

  // Ruby uses RuboCop
  if (language === 'ruby') {
    const ruboCopConfig = `AllCops:
  NewCops: enable
  TargetRubyVersion: 3.2
  Exclude:
    - 'db/schema.rb'
    - 'bin/**/*'
    - 'vendor/**/*'
    - 'node_modules/**/*'

Style/Documentation:
  Enabled: false

Style/FrozenStringLiteralComment:
  Enabled: true

Metrics/MethodLength:
  Max: 20

Metrics/AbcSize:
  Max: 25

Layout/LineLength:
  Max: 120

Lint/UnusedMethodArgument:
  AllowUnusedKeywordArguments: true

Style/StringLiterals:
  EnforcedStyle: double_quotes
`;
    writeFileSync(path.join(root, '.rubocop.yml'), ruboCopConfig, 'utf-8');
    return;
  }

  // JavaScript/TypeScript ESLint
  const packages: string[] = ['eslint'];
  let configContent = '';

  if (language === 'typescript') {
    packages.push('@typescript-eslint/parser', '@typescript-eslint/eslint-plugin');
  }

  if (frontendFramework === 'nextjs') {
    packages.push('eslint-config-next');
    configContent = `import { dirname } from "path";
import { fileURLToPath } from "url";
import { FlatCompat } from "@eslint/eslintrc";

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const compat = new FlatCompat({ baseDirectory: __dirname });

export default [
  ...compat.extends("next/core-web-vitals"),
  {
    rules: {
      "no-console": "warn",
      "no-unused-vars": "off",
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
    },
  },
];
`;
    packages.push('@eslint/eslintrc');
  } else if (frontendFramework === 'react') {
    packages.push('eslint-plugin-react', 'eslint-plugin-react-hooks');
    configContent = `import tsPlugin from "@typescript-eslint/eslint-plugin";
import tsParser from "@typescript-eslint/parser";
import reactPlugin from "eslint-plugin-react";
import reactHooksPlugin from "eslint-plugin-react-hooks";

export default [
  {
    files: ["**/*.{ts,tsx}"],
    plugins: {
      "@typescript-eslint": tsPlugin,
      react: reactPlugin,
      "react-hooks": reactHooksPlugin,
    },
    languageOptions: {
      parser: tsParser,
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
    rules: {
      "no-console": "warn",
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",
    },
  },
];
`;
  } else {
    configContent = `import tsPlugin from "@typescript-eslint/eslint-plugin";
import tsParser from "@typescript-eslint/parser";

export default [
  {
    files: ["**/*.{ts,js}"],
    plugins: { "@typescript-eslint": tsPlugin },
    languageOptions: { parser: tsParser },
    rules: {
      "no-console": "warn",
      "@typescript-eslint/no-unused-vars": ["warn", { argsIgnorePattern: "^_" }],
      "@typescript-eslint/no-explicit-any": "warn",
    },
  },
];
`;
  }

  // Install packages
  const cmd = `${installCmd(packageManager)} ${packages.join(' ')}`;
  execSync(cmd, { cwd: root, stdio: 'pipe' });

  // Write config
  writeFileSync(path.join(root, 'eslint.config.js'), configContent, 'utf-8');
}
