// 配置加载 — 所有脚本共用的默认值和读取逻辑

const fs = require('fs');
const path = require('path');

const DEFAULTS = {
  harness: 'claude',
  projectName: 'Tinyman',
  projectDesc: '',
  imPlatform: 'lark',
  pollInterval: 1,
  pollCooldown: 15,
  dirs: {
    repos: 'repos',
    knowledge: 'knowledge-base',
    messages: 'messages',
    tasks: 'tasks',
    worklogs: 'worklogs',
  },
  agents: [],
};

function loadConfig(rootDir) {
  let config;
  try {
    config = JSON.parse(fs.readFileSync(path.join(rootDir, 'tinyman.config.json'), 'utf8'));
  } catch {
    config = {};
  }

  // 合并默认值
  return {
    ...DEFAULTS,
    ...config,
    dirs: { ...DEFAULTS.dirs, ...(config.dirs || {}) },
  };
}

module.exports = { loadConfig, DEFAULTS };
