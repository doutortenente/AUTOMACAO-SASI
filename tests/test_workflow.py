import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / "n8n/workflows/sasi-clinical-compile.json"
SERVICE = ROOT / "services/extracao-clinica-sasi.service"
INSTALLER = ROOT / "scripts/install-local.sh"


class WorkflowContractTests(unittest.TestCase):
    def test_workflow_is_authenticated_and_local_only(self):
        data = json.loads(WORKFLOW.read_text(encoding="utf-8"))
        self.assertEqual(data["name"], "SASI - Compilar Extração Clínica")
        self.assertTrue(data["active"])
        nodes = {node["name"]: node for node in data["nodes"]}
        webhook = nodes["Entrada Clínica"]
        self.assertEqual(webhook["parameters"]["httpMethod"], "POST")
        self.assertEqual(webhook["parameters"]["path"], "sasi-clinical-compile")
        self.assertEqual(webhook["parameters"]["authentication"], "headerAuth")
        motor = nodes["Motor Clínico Local"]
        self.assertEqual(motor["parameters"]["url"], "http://127.0.0.1:8765/v1/compile")
        self.assertEqual(data["settings"]["saveDataErrorExecution"], "none")
        self.assertEqual(data["settings"]["saveDataSuccessExecution"], "none")
        self.assertNotIn("SUPABASE", WORKFLOW.read_text(encoding="utf-8"))
        self.assertNotIn("API_KEY", WORKFLOW.read_text(encoding="utf-8"))

    def test_service_is_bound_to_localhost_and_hardened(self):
        text = SERVICE.read_text(encoding="utf-8")
        self.assertIn("--host 127.0.0.1", text)
        self.assertIn("NoNewPrivileges=true", text)
        self.assertIn("ProtectSystem=strict", text)
        self.assertIn("MemoryMax=256M", text)

    def test_installer_tem_check_sem_mutacao_e_descoberta_dinamica(self):
        text = INSTALLER.read_text(encoding="utf-8")
        self.assertIn('MODE="${1:-install}"', text)
        self.assertIn('if [[ "$MODE" == "--check" ]]', text)
        self.assertNotIn("v24.16.0", text)
        self.assertIn("command -v n8n", text)
        self.assertIn("systemctl --user restart extracao-clinica-sasi.service", text)

    def test_installer_tem_rollback_do_banco(self):
        text = INSTALLER.read_text(encoding="utf-8")
        self.assertIn("rollback_database", text)
        self.assertIn('install -m 0600 "$BACKUP" "$N8N_HOME/database.sqlite"', text)


if __name__ == "__main__":
    unittest.main()
