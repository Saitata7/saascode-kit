import type { Finding, ScanResult } from '../types/findings.js';

interface SarifRun {
  tool: {
    driver: {
      name: string;
      version: string;
      informationUri: string;
      rules: SarifRule[];
    };
  };
  results: SarifResult[];
}

interface SarifRule {
  id: string;
  shortDescription: { text: string };
  properties?: { confidence: string; tier: string };
}

interface SarifResult {
  ruleId: string;
  level: string;
  message: { text: string };
  locations: {
    physicalLocation: {
      artifactLocation: { uri: string };
      region: { startLine: number };
    };
  }[];
  properties?: { confidence: string; tier: string; fix?: string };
}

function severityToLevel(severity: string): string {
  switch (severity) {
    case 'critical': return 'error';
    case 'warning': return 'warning';
    default: return 'note';
  }
}

/**
 * Convert scan results to SARIF 2.1.0 format.
 */
export function toSarif(result: ScanResult): object {
  const rulesMap = new Map<string, SarifRule>();

  for (const finding of result.findings) {
    if (!rulesMap.has(finding.ruleId)) {
      rulesMap.set(finding.ruleId, {
        id: finding.ruleId,
        shortDescription: { text: finding.issue },
        properties: {
          confidence: finding.confidence,
          tier: finding.tier,
        },
      });
    }
  }

  const run: SarifRun = {
    tool: {
      driver: {
        name: 'saascode',
        version: '2.0.0',
        informationUri: 'https://github.com/Saitata7/saascode-kit',
        rules: Array.from(rulesMap.values()),
      },
    },
    results: result.findings.map(f => ({
      ruleId: f.ruleId,
      level: severityToLevel(f.severity),
      message: { text: f.issue },
      locations: [
        {
          physicalLocation: {
            artifactLocation: { uri: f.file },
            region: { startLine: f.line },
          },
        },
      ],
      properties: {
        confidence: f.confidence,
        tier: f.tier,
        fix: f.fix,
      },
    })),
  };

  return {
    $schema: 'https://raw.githubusercontent.com/oasis-tcs/sarif-spec/main/sarif-2.1/schema/sarif-schema-2.1.0.json',
    version: '2.1.0',
    runs: [run],
  };
}
