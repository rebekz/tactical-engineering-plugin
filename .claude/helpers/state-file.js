/**
 * State File Helper Functions
 *
 * Provides utilities for managing task persistence state files.
 * State files are stored at .claude/specs/<spec-name>/state.json
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

/**
 * Sanitize spec path to directory name
 * @param {string} specPath - Path to spec file (e.g., "specs/user-auth.md")
 * @returns {string} Sanitized directory name (e.g., "user-auth")
 */
function sanitizeSpecName(specPath) {
  // Remove specs/ prefix if present
  let name = specPath.replace(/^specs\//, '');

  // Remove .md extension
  name = name.replace(/\.md$/, '');

  // Replace remaining / with -
  name = name.replace(/\//g, '-');

  return name;
}

/**
 * Get state file path from spec path
 * @param {string} specPath - Path to spec file
 * @param {string} projectRoot - Project root directory (default: current working dir)
 * @returns {string} Full path to state file
 */
function getStateFilePath(specPath, projectRoot = process.cwd()) {
  const sanitizedName = sanitizeSpecName(specPath);
  return path.join(projectRoot, '.claude', 'specs', sanitizedName, 'state.json');
}

/**
 * Calculate SHA256 checksum of spec file
 * @param {string} specPath - Path to spec file
 * @returns {string} Checksum in format "sha256:hexdigest"
 */
function calculateChecksum(specPath) {
  try {
    const content = fs.readFileSync(specPath, 'utf8');
    const hash = crypto.createHash('sha256').update(content).digest('hex');
    return `sha256:${hash}`;
  } catch (error) {
    throw new Error(`Failed to calculate checksum for ${specPath}: ${error.message}`);
  }
}

/**
 * Read state file from disk
 * @param {string} specPath - Path to spec file
 * @returns {object|null} Parsed state object or null if file doesn't exist
 */
function readStateFile(specPath) {
  const statePath = getStateFilePath(specPath);

  try {
    const content = fs.readFileSync(statePath, 'utf8');
    return JSON.parse(content);
  } catch (error) {
    if (error.code === 'ENOENT') {
      // File doesn't exist - not an error, just return null
      return null;
    }

    // File exists but is corrupted or unreadable
    if (error instanceof SyntaxError) {
      throw new Error(`State file is corrupted (invalid JSON): ${statePath}`);
    }

    throw new Error(`Failed to read state file: ${error.message}`);
  }
}

/**
 * Write state file to disk
 * @param {string} specPath - Path to spec file
 * @param {object} state - State object to write
 */
function writeStateFile(specPath, state) {
  const statePath = getStateFilePath(specPath);
  const stateDir = path.dirname(statePath);

  try {
    // Create directory if it doesn't exist
    if (!fs.existsSync(stateDir)) {
      fs.mkdirSync(stateDir, { recursive: true });
    }

    // Write state file
    fs.writeFileSync(statePath, JSON.stringify(state, null, 2), 'utf8');
  } catch (error) {
    throw new Error(`Failed to write state file to ${statePath}: ${error.message}`);
  }
}

/**
 * Update a specific task in the state file
 * @param {string} specPath - Path to spec file
 * @param {string} taskId - Task ID to update
 * @param {object} updates - Fields to update in the task
 */
function updateTaskInState(specPath, taskId, updates) {
  const state = readStateFile(specPath);

  if (!state) {
    throw new Error(`No state file found for ${specPath}`);
  }

  const taskIndex = state.tasks.findIndex(t => t.id === taskId);

  if (taskIndex === -1) {
    throw new Error(`Task ${taskId} not found in state file`);
  }

  // Merge updates into task
  state.tasks[taskIndex] = {
    ...state.tasks[taskIndex],
    ...updates
  };

  // Update lastUpdated timestamp
  state.build.lastUpdated = new Date().toISOString();

  // Write updated state
  writeStateFile(specPath, state);
}

/**
 * Delete state file and directory
 * @param {string} specPath - Path to spec file
 */
function deleteStateFile(specPath) {
  const statePath = getStateFilePath(specPath);
  const stateDir = path.dirname(statePath);

  try {
    // Delete state file if it exists
    if (fs.existsSync(statePath)) {
      fs.unlinkSync(statePath);
    }

    // Delete directory if it's empty
    if (fs.existsSync(stateDir) && fs.readdirSync(stateDir).length === 0) {
      fs.rmdirSync(stateDir);
    }
  } catch (error) {
    throw new Error(`Failed to delete state file: ${error.message}`);
  }
}

/**
 * Rebuild state from TaskList (for auto-repair)
 * @param {Array} tasks - Array of tasks from TaskList
 * @param {string} specPath - Path to spec file
 * @returns {object} Rebuilt state object
 */
function rebuildStateFromTaskList(tasks, specPath) {
  const checksum = calculateChecksum(specPath);
  const now = new Date().toISOString();

  return {
    build: {
      specPath: specPath,
      specChecksum: checksum,
      startedAt: now,
      lastUpdated: now,
      totalTasks: tasks.length
    },
    tasks: tasks.map(t => ({
      id: t.id,
      subject: t.subject,
      description: t.description,
      status: t.status || 'pending',
      activeForm: t.activeForm,
      blockedBy: t.blockedBy || [],
      agentType: t.agentType || 'general-purpose',
      // Don't include agentId - we don't have it from TaskList
    })),
    artifacts: [],
    validation: {
      commandsRun: [],
      acceptanceCriteria: []
    }
  };
}

// Export functions for use in commands
module.exports = {
  sanitizeSpecName,
  getStateFilePath,
  calculateChecksum,
  readStateFile,
  writeStateFile,
  updateTaskInState,
  deleteStateFile,
  rebuildStateFromTaskList
};
