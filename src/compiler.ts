/**
 * Metal Shader Compiler
 * Handles compilation of Metal shaders using xcrun
 */

import { exec } from 'child_process';
import { promisify } from 'util';
import * as fs from 'fs/promises';
import * as path from 'path';
import * as os from 'os';
import * as crypto from 'crypto';

const execAsync = promisify(exec);

export interface CompilationResult {
  success: boolean;
  outputPath?: string;
  errors: CompilationError[];
  warnings: CompilationWarning[];
  compileTime: number;
}

export interface CompilationError {
  line: number;
  column: number;
  message: string;
  code?: string;
}

export interface CompilationWarning {
  line: number;
  column: number;
  message: string;
}

export interface CompilationOptions {
  target: 'air' | 'metallib' | 'spirv';
  optimize: boolean;
  includePaths?: string[];
}

export interface ValidationResult {
  valid: boolean;
  errors: CompilationError[];
  warnings: CompilationWarning[];
  suggestions: string[];
}

/**
 * Compile Metal shader code
 */
export async function compileShader(
  code: string,
  options: CompilationOptions = { target: 'air', optimize: false }
): Promise<CompilationResult> {
  const startTime = Date.now();
  const hash = crypto.createHash('md5').update(code).digest('hex');
  const tempDir = path.join(os.tmpdir(), 'metal-shader-mcp', hash);
  
  await fs.mkdir(tempDir, { recursive: true });
  
  const sourcePath = path.join(tempDir, 'shader.metal');
  const outputPath = path.join(tempDir, `shader.${options.target}`);
  
  try {
    // Write source code to temp file
    await fs.writeFile(sourcePath, code);
    
    // Build compilation command
    let command = `xcrun -sdk macosx metal`;
    
    // Add compilation flags
    if (options.optimize) {
      command += ' -O3';
    }
    
    // Add include paths
    if (options.includePaths) {
      for (const includePath of options.includePaths) {
        command += ` -I ${includePath}`;
      }
    }
    
    // Set target format
    switch (options.target) {
      case 'air':
        command += ` -c ${sourcePath} -o ${outputPath}`;
        break;
      case 'metallib':
        // First compile to AIR, then create metallib
        const airPath = path.join(tempDir, 'shader.air');
        command += ` -c ${sourcePath} -o ${airPath}`;
        const { stderr: airErr } = await execAsync(command);
        if (airErr) {
          return parseCompilationResult(airErr, false, Date.now() - startTime);
        }
        command = `xcrun -sdk macosx metallib ${airPath} -o ${outputPath}`;
        break;
      case 'spirv':
        // Metal to SPIR-V requires additional tooling
        command += ` -c ${sourcePath} -o ${outputPath}.air`;
        // Note: Would need spirv-cross or similar for full conversion
        break;
    }
    
    // Execute compilation
    const { stdout, stderr } = await execAsync(command);
    
    // Check if output file was created
    const outputExists = await fs.access(outputPath).then(() => true).catch(() => false);
    
    if (!outputExists && !stderr) {
      throw new Error('Compilation produced no output');
    }
    
    // Parse compiler output
    const result = parseCompilationResult(stderr || '', outputExists, Date.now() - startTime);
    if (outputExists) {
      result.outputPath = outputPath;
    }
    
    return result;
    
  } catch (error: any) {
    // Handle compilation errors
    if (error.stderr) {
      return parseCompilationResult(error.stderr, false, Date.now() - startTime);
    }
    throw error;
  }
}

/**
 * Validate Metal shader syntax
 */
export async function validateShader(code: string): Promise<ValidationResult> {
  const result: ValidationResult = {
    valid: true,
    errors: [],
    warnings: [],
    suggestions: [],
  };
  
  // Check for common Metal shader patterns
  const checks = [
    {
      pattern: /\bfragment\s+\w+\s+\w+\s*\(/,
      message: 'Fragment function detected',
      type: 'info',
    },
    {
      pattern: /\bvertex\s+\w+\s+\w+\s*\(/,
      message: 'Vertex function detected',
      type: 'info',
    },
    {
      pattern: /\[\[stage_in\]\]/,
      message: 'Stage input attribute found',
      type: 'info',
    },
    {
      pattern: /\[\[buffer\(\d+\)\]\]/,
      message: 'Buffer binding found',
      type: 'info',
    },
    {
      pattern: /\[\[texture\(\d+\)\]\]/,
      message: 'Texture binding found',
      type: 'info',
    },
  ];
  
  // Performance suggestions
  if (code.includes('for') && code.includes('for')) {
    result.suggestions.push('Consider unrolling nested loops for better performance');
  }
  
  if (code.includes('pow(')) {
    result.suggestions.push('Consider using multiplication instead of pow() for small exponents');
  }
  
  if (code.includes('sin(') || code.includes('cos(')) {
    result.suggestions.push('Consider using fast math approximations for trigonometric functions if precision is not critical');
  }
  
  // Try actual compilation for full validation
  try {
    const compilationResult = await compileShader(code, { target: 'air', optimize: false });
    result.valid = compilationResult.success;
    result.errors = compilationResult.errors;
    result.warnings = compilationResult.warnings;
  } catch (error) {
    result.valid = false;
    result.errors.push({
      line: 0,
      column: 0,
      message: `Validation error: ${error}`,
    });
  }
  
  return result;
}

/**
 * Parse compiler output for errors and warnings
 */
function parseCompilationResult(
  output: string,
  success: boolean,
  compileTime: number
): CompilationResult {
  const errors: CompilationError[] = [];
  const warnings: CompilationWarning[] = [];
  
  const lines = output.split('\n');
  
  for (const line of lines) {
    // Parse Metal compiler error format
    // Example: shader.metal:10:5: error: use of undeclared identifier 'foo'
    const errorMatch = line.match(/^(.+):(\d+):(\d+):\s*error:\s*(.+)$/);
    if (errorMatch) {
      errors.push({
        line: parseInt(errorMatch[2], 10),
        column: parseInt(errorMatch[3], 10),
        message: errorMatch[4],
      });
      continue;
    }
    
    // Parse warnings
    const warningMatch = line.match(/^(.+):(\d+):(\d+):\s*warning:\s*(.+)$/);
    if (warningMatch) {
      warnings.push({
        line: parseInt(warningMatch[2], 10),
        column: parseInt(warningMatch[3], 10),
        message: warningMatch[4],
      });
      continue;
    }
  }
  
  return {
    success: success && errors.length === 0,
    errors,
    warnings,
    compileTime,
  };
}