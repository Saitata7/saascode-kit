export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'PATCH' | 'DELETE';

export interface Endpoint {
  method: HttpMethod;
  rawPath: string;
  normalizedPath: string;
  file: string;
  line: number;
  framework: string;
  confidence: number;
  params: string[];
}

export interface ParityResult {
  matched: { frontend: Endpoint; backend: Endpoint }[];
  missingBackend: Endpoint[];
  orphanedBackend: Endpoint[];
  methodMismatches: { path: string; frontend: Endpoint; backend: Endpoint }[];
  paramMismatches: { path: string; frontend: Endpoint; backend: Endpoint }[];
}

export interface CheckOptions {
  frontendPath?: string;
  backendPath?: string;
  framework?: string;
  apiPrefix?: string;
  format?: 'text' | 'json' | 'sarif';
  verbose?: boolean;
}

export interface ScanContext {
  root: string;
  frontendPath: string;
  backendPath: string;
  framework: string;
  apiPrefix: string;
}
