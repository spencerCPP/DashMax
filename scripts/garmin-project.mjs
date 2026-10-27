import { cpSync, mkdirSync, writeFileSync } from 'node:fs';
import path from 'node:path';

export function prepareBuildProject(project, activityData) {
  if (!activityData) return project;
  const destination = path.join(project, 'bin', 'fit-project');
  mkdirSync(destination, { recursive: true });
  // Copy only build inputs; never copy signing keys, outputs, or node_modules.
  for (const entry of ['manifest.xml', 'monkey.jungle', 'source', 'test', 'resources']) {
    cpSync(path.join(project, entry), path.join(destination, entry), { recursive: true });
  }
  // Force the data source regardless of any previously saved simulator settings.
  writeFileSync(path.join(destination, 'source', 'BuildMode.mc'),
    'module BuildMode {\n    const ACTIVITY_DATA = true;\n}\n');
  return destination;
}
