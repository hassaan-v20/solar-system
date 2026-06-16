const STORAGE_KEY = "stellar_settings";

export interface SettingsData {
  mouseSensitivity: number;
  showCrosshair: boolean;
  showMarkers: boolean;
  showDroneBars: boolean;
  showEnemyIndicators: boolean;
  showPlayerBars: boolean;
}

const DEFAULTS: SettingsData = {
  mouseSensitivity: 0.05,
  showCrosshair: true,
  showMarkers: true,
  showDroneBars: true,
  showEnemyIndicators: true,
  showPlayerBars: true,
};

function load(): SettingsData {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return { ...DEFAULTS, ...JSON.parse(raw) };
  } catch { /* corrupted — use defaults */ }
  return { ...DEFAULTS };
}

function save(data: SettingsData): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
  } catch { /* quota exceeded — silently ignore */ }
}

export const settings: SettingsData = load();

export function commitSettings(): void {
  save(settings);
}
