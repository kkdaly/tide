// Harness 预设配置
// Usage: const presets = require('./harness-presets'); const h = presets['claude'];
//
// 注意: Claude Code 已在生产验证。Codex/Trae/OpenClaw 的 busy/idle
// 正则为理论值，首次使用可能需要根据实际 UI 输出调整。
// 首次条款自动接受仅支持 Claude Code，其他 harness 需手动处理。

const presets = {
  claude: {
    name: 'Claude Code',
    startCmd: 'claude --dangerously-skip-permissions',
    busyPattern: /(thinking|· still|Esc to interrupt|ctrl\+o to expand|Do you want to|Waiting…)/,
    idlePattern: /❯|[\$#>] /,
    configDir: '.claude',
    needsTermsAccept: true,
  },

  codex: {
    name: 'Codex CLI',
    startCmd: 'codex exec',
    busyPattern: /(Working…|Generating…|Processing)/,
    idlePattern: /(▸|❯)/,
    configDir: '.codex',
    needsTermsAccept: false,
  },

  trae: {
    name: 'Trae CLI',
    startCmd: 'trae',
    busyPattern: /(Processing|Working|Generating)/,
    idlePattern: /(❯|▸|\$) /,
    configDir: '.trae',
    needsTermsAccept: false,
  },

  openclaw: {
    name: 'OpenClaw',
    startCmd: 'openclaw serve',
    busyPattern: /(Processing|Working|Thinking)/,
    idlePattern: /(❯|\$) /,
    configDir: '.openclaw',
    needsTermsAccept: false,
  },
};

function resolve(harnessKey) {
  const preset = presets[harnessKey];
  if (!preset) {
    const available = Object.keys(presets).join(', ');
    throw new Error(`Unknown harness: ${harnessKey}. Available: ${available}`);
  }
  return preset;
}

module.exports = { presets, resolve };
