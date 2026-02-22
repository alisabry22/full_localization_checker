import * as vscode from 'vscode';
import * as cp from 'child_process';
import * as path from 'path';

export function activate(context: vscode.ExtensionContext) {
    console.log('Localization Checker is now active!');

    // Register the Quick Fix Provider
    context.subscriptions.push(
        vscode.languages.registerCodeActionsProvider('dart', new LocalizationActionProvider(), {
            providedCodeActionKinds: LocalizationActionProvider.providedCodeActionKinds
        })
    );

    // Register the actual command that executes the Dart script
    context.subscriptions.push(
        vscode.commands.registerCommand('loc-checker.extractSingle', runExtraction)
    );
}

export function deactivate() { }

/**
 * Provides code actions for Dart string literals.
 */
export class LocalizationActionProvider implements vscode.CodeActionProvider {
    public static readonly providedCodeActionKinds = [
        vscode.CodeActionKind.QuickFix
    ];

    public provideCodeActions(
        document: vscode.TextDocument,
        range: vscode.Range | vscode.Selection,
        context: vscode.CodeActionContext,
        token: vscode.CancellationToken
    ): vscode.CodeAction[] | undefined {

        // Very basic check if we are on a string literal (we can be more robust using a regex or relying on dart parsing)
        // For now, let's just surface it anywhere inside a dart file to be safe,
        // or specifically if the line contains a string.
        const line = document.lineAt(range.start.line).text;
        if (!line.includes("'") && !line.includes('"')) {
            return;
        }

        const extractAction = this.createCommand();
        return [extractAction];
    }

    private createCommand(): vscode.CodeAction {
        const action = new vscode.CodeAction('💡 Extract and Translate String', vscode.CodeActionKind.QuickFix);
        action.command = {
            command: 'loc-checker.extractSingle',
            title: 'Extract and Translate String',
            tooltip: 'Extract this string to ARB and translate it using loc_checker'
        };
        action.isPreferred = true;
        return action;
    }
}

/**
 * Runs the loc_checker Dart CLI to extract the string.
 */
async function runExtraction() {
    const editor = vscode.window.activeTextEditor;
    if (!editor) {
        return;
    }

    const document = editor.document;
    const position = editor.selection.active;
    const filePath = document.uri.fsPath;

    // Save document before running tool to ensure file matches buffer
    await document.save();

    // Find the Dart script path
    // Assuming the extension is running in a subfolder of the main Dart package
    // or it needs to be configured.
    const workspaceFolder = vscode.workspace.getWorkspaceFolder(document.uri);
    const dartScriptPath = workspaceFolder
        ? path.join(workspaceFolder.uri.fsPath, 'bin', 'loc_checker.dart')
        : 'loc_checker'; // Fallback to global if installed

    const args = [
        'run',
        dartScriptPath, // Fallback if no script found? Actually `dart run bin/loc_checker.dart` is safer
        '--extract-single',
        `--file=${filePath}`,
        `--line=${position.line + 1}`, // line is 0-indexed in VS Code but 1-indexed in loc_checker
        `--col=${position.character + 1}`
    ];

    vscode.window.withProgress({
        location: vscode.ProgressLocation.Notification,
        title: "Extracting and Translating...",
        cancellable: false
    }, async (progress) => {
        return new Promise<void>((resolve, reject) => {
            // Execute the Dart CLI command
            cp.execFile('dart', args, { cwd: workspaceFolder?.uri.fsPath || path.dirname(filePath) }, (error, stdout, stderr) => {
                if (error) {
                    vscode.window.showErrorMessage(`Extraction failed: ${error.message} \n ${stderr}`);
                    reject(error);
                    return;
                }

                vscode.window.showInformationMessage('Successfully extracted and translated string!');
                resolve();
            });
        });
    });
}