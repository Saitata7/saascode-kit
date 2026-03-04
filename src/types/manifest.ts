/**
 * Manifest YAML schema as TypeScript interfaces.
 * All fields optional except project.name.
 */

export interface ManifestProject {
  name: string;
  description?: string;
  type?: 'single-tenant' | 'multi-tenant-saas' | 'marketplace' | 'platform' | 'api-service';
  domain?: string;
  port?: number;
}

export interface ManifestFrontend {
  framework?: 'nextjs' | 'react' | 'vue' | 'svelte' | 'angular';
  version?: string;
  ui_library?: string;
  css?: string;
  state?: string;
}

export interface ManifestBackend {
  framework?: 'nestjs' | 'express' | 'fastify' | 'hono' | 'django' | 'rails' | 'spring' | 'laravel' | 'gin' | 'flask' | 'fastapi' | 'chi' | 'mux';
  version?: string;
  orm?: 'prisma' | 'typeorm' | 'drizzle' | 'sequelize' | 'mongoose' | 'sqlalchemy' | 'activerecord' | 'django';
  database?: 'postgresql' | 'mysql' | 'mongodb' | 'sqlite';
  cache?: string;
  queue?: string;
}

export interface ManifestStack {
  frontend?: ManifestFrontend;
  backend?: ManifestBackend;
  language?: 'typescript' | 'javascript' | 'python' | 'ruby' | 'go' | 'java' | 'kotlin' | 'php' | 'rust';
}

export interface ManifestRole {
  name: string;
  level: string;
}

export interface ManifestAuth {
  provider?: string;
  multi_tenant?: boolean;
  roles?: ManifestRole[];
  guard_pattern?: 'decorator' | 'middleware' | 'policy';
  session?: 'jwt' | 'session' | 'cookie';
}

export interface ManifestBilling {
  enabled?: boolean;
  provider?: string;
  model?: 'subscription' | 'usage-based' | 'one-time' | 'freemium' | 'hybrid';
  webhooks?: boolean;
}

export interface ManifestTenancy {
  enabled?: boolean;
  isolation?: 'row-level' | 'schema-level' | 'database-level';
  identifier?: string;
  context_source?: 'header' | 'subdomain' | 'path' | 'jwt-claim';
}

export interface ManifestAI {
  enabled?: boolean;
  providers?: string[];
  features?: string[];
  vector_db?: string;
  streaming?: boolean;
  structured_output?: boolean;
  cost_tracking?: boolean;
  guardrails?: boolean;
}

export interface ManifestIntegration {
  name: string;
  type: string;
  has_webhooks?: boolean;
}

export interface ManifestInfra {
  frontend_host?: string;
  backend_host?: string;
  ci_provider?: 'github' | 'gitlab' | 'bitbucket' | 'circleci';
}

export interface ManifestSecurity {
  owasp_web?: boolean;
  owasp_llm?: boolean;
  compliance?: string[];
  secret_scanning?: boolean;
  dependency_scanning?: boolean;
}

export interface ManifestReview {
  pre_commit?: boolean;
  pre_push?: boolean;
  ci_on_pr?: boolean;
  auto_comment_pr?: boolean;
}

export interface ManifestPaths {
  frontend?: string;
  backend?: string;
  shared?: string;
  schema?: string;
  api_client?: string;
  components?: string;
}

export interface ManifestPattern {
  id: string;
  description: string;
  correct?: string;
  wrong?: string;
}

export interface ManifestPatterns {
  critical?: ManifestPattern[];
  anti_patterns?: string[];
  colors?: Record<string, string>;
}

export interface Manifest {
  project: ManifestProject;
  stack?: ManifestStack;
  auth?: ManifestAuth;
  billing?: ManifestBilling;
  tenancy?: ManifestTenancy;
  ai?: ManifestAI;
  integrations?: ManifestIntegration[];
  infra?: ManifestInfra;
  security?: ManifestSecurity;
  review?: ManifestReview;
  paths?: ManifestPaths;
  patterns?: ManifestPatterns;
}
