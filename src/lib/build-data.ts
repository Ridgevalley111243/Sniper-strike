// Content for the static build. In CI it's read from Supabase; set
// SITE_DATA_FILE to a JSON snapshot ({ projects, settings, version }) to build
// without network access.
import fs from 'node:fs';
import {
  fetchContentVersion,
  fetchProjects,
  fetchSettings,
  normalizeProject,
  normalizeSettings,
  type Project,
  type Settings,
} from './content';

async function load(): Promise<{ projects: Project[]; settings: Settings; version: string }> {
  const file = process.env.SITE_DATA_FILE;
  if (file) {
    const d = JSON.parse(fs.readFileSync(file, 'utf8'));
    return {
      projects: (d.projects ?? []).map(normalizeProject),
      settings: normalizeSettings(d.settings),
      version: String(d.version ?? 'snapshot'),
    };
  }
  const [projects, settings, version] = await Promise.all([fetchProjects(), fetchSettings(), fetchContentVersion()]);
  return { projects, settings, version };
}

export const { projects, settings, version } = await load();
