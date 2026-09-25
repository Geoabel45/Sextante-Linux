#!/usr/bin/env python3

import json
import re
import subprocess
import sys

from PyQt6.QtCore import QProcess
from PyQt6.QtWidgets import (
    QApplication,
    QCheckBox,
    QComboBox,
    QFormLayout,
    QHBoxLayout,
    QLabel,
    QLineEdit,
    QMainWindow,
    QMessageBox,
    QPushButton,
    QTextEdit,
    QVBoxLayout,
    QWidget,
)

ENGINE = "/opt/sextanteproj/installer/install.sh"
MIN_SIZE = 10 * 1024**3


def command_output(*args):
    try:
        return subprocess.check_output(
            args,
            text=True,
            stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        return ""


def root_disk():
    source = command_output("findmnt", "-no", "SOURCE", "/")

    if not source.startswith("/dev/"):
        return ""

    parent = command_output("lsblk", "-no", "PKNAME", source)

    if parent:
        return "/dev/" + parent

    return source


def contains_live_label(device):
    def walk(node):
        label = node.get("label") or ""

        if label == "ARCHISO_EFI" or label.startswith("SEXTANTE_"):
            return True

        return any(walk(child) for child in node.get("children", []))

    return walk(device)


class Installer(QMainWindow):
    def __init__(self):
        super().__init__()

        self.process = None
        self.disk_paths = []

        self.setWindowTitle("Instalar Sextante Linux")
        self.resize(760, 620)

        central = QWidget()
        self.setCentralWidget(central)

        layout = QVBoxLayout(central)

        title = QLabel("<h1>Instalar Sextante Linux</h1>")
        subtitle = QLabel(
            "Instalador gráfico oficial de Sextante Linux"
        )

        layout.addWidget(title)
        layout.addWidget(subtitle)

        warning = QLabel(
            "<b>Advertencia:</b> la instalación eliminará completamente "
            "el contenido del disco seleccionado."
        )
        warning.setWordWrap(True)
        layout.addWidget(warning)

        form = QFormLayout()

        disk_row = QHBoxLayout()

        self.disk_combo = QComboBox()
        self.refresh_button = QPushButton("Actualizar discos")
        self.refresh_button.clicked.connect(self.load_disks)

        disk_row.addWidget(self.disk_combo)
        disk_row.addWidget(self.refresh_button)

        form.addRow("Disco destino:", disk_row)

        self.username = QLineEdit()
        self.username.setPlaceholderText("sextante")
        form.addRow("Usuario:", self.username)
        self.keyboard = QComboBox()
        self.keyboard.addItem("Español Latinoamericano", "latam")
        self.keyboard.addItem("Español de España", "es")
        self.keyboard.addItem("Inglés (Estados Unidos)", "us")
        form.addRow("Teclado:", self.keyboard)

        self.password = QLineEdit()
        self.password.setEchoMode(QLineEdit.EchoMode.Password)
        form.addRow("Contraseña:", self.password)

        self.password2 = QLineEdit()
        self.password2.setEchoMode(QLineEdit.EchoMode.Password)
        form.addRow("Confirmar contraseña:", self.password2)

        layout.addLayout(form)

        self.confirm = QCheckBox(
            "Entiendo que el disco seleccionado será borrado completamente."
        )
        layout.addWidget(self.confirm)

        self.install_button = QPushButton("Instalar Sextante Linux")
        self.install_button.clicked.connect(self.start_install)
        layout.addWidget(self.install_button)

        self.log = QTextEdit()
        self.log.setReadOnly(True)
        self.log.setPlaceholderText(
            "El progreso de la instalación aparecerá aquí."
        )
        layout.addWidget(self.log)

        self.load_disks()

    def load_disks(self):
        self.disk_combo.clear()
        self.disk_paths.clear()

        try:
            raw = subprocess.check_output(
                [
                    "lsblk", "-J", "-b",
                    "-o",
                    "NAME,PATH,SIZE,TYPE,MODEL,TRAN,LABEL,MOUNTPOINTS",
                ],
                text=True,
            )
            data = json.loads(raw)
        except Exception as exc:
            QMessageBox.critical(
                self,
                "Error",
                f"No fue posible detectar los discos:\n{exc}",
            )
            return

        system_disk = root_disk()

        for disk in data.get("blockdevices", []):
            if disk.get("type") != "disk":
                continue

            path = disk.get("path") or ""

            try:
                size = int(disk.get("size") or 0)
            except ValueError:
                size = 0

            if size < MIN_SIZE:
                continue

            if path == system_disk:
                continue

            if contains_live_label(disk):
                continue

            model = (disk.get("model") or "Sin modelo").strip()
            transport = (disk.get("tran") or "").strip()
            gib = size / (1024**3)

            text = f"{path} — {gib:.1f} GiB — {model}"

            if transport:
                text += f" — {transport}"

            self.disk_combo.addItem(text)
            self.disk_paths.append(path)

        if not self.disk_paths:
            self.disk_combo.addItem("No hay discos disponibles")
            self.install_button.setEnabled(False)
        else:
            self.install_button.setEnabled(True)

    def start_install(self):
        if not self.disk_paths:
            return

        disk = self.disk_paths[self.disk_combo.currentIndex()]
        keyboard = self.keyboard.currentData()
        username = self.username.text().strip()
        username = self.username.text().strip()
        password = self.password.text()
        password2 = self.password2.text()

        if not re.fullmatch(r"[a-z_][a-z0-9_-]*", username):
            QMessageBox.warning(
                self,
                "Usuario inválido",
                "Utiliza letras minúsculas, números, _ o -.",
            )
            return

        if not password:
            QMessageBox.warning(
                self,
                "Contraseña",
                "La contraseña no puede estar vacía.",
            )
            return

        if password != password2:
            QMessageBox.warning(
                self,
                "Contraseña",
                "Las contraseñas no coinciden.",
            )
            return

        if not self.confirm.isChecked():
            QMessageBox.warning(
                self,
                "Confirmación requerida",
                "Debes confirmar que entiendes que el disco será borrado.",
            )
            return

        answer = QMessageBox.question(
            self,
            "Confirmar instalación",
            (
                f"Se eliminará TODO el contenido de:\n\n"
                f"{disk}\n\n"
                f"Usuario: {username}\n\n"
                "¿Deseas iniciar la instalación?"
            ),
            QMessageBox.StandardButton.Yes |
            QMessageBox.StandardButton.No,
            QMessageBox.StandardButton.No,
        )

        if answer != QMessageBox.StandardButton.Yes:
            return

        self.log.clear()
        self.log.append(f"Disco destino: {disk}")
        self.log.append("Iniciando instalación...\n")

        self.install_button.setEnabled(False)
        self.refresh_button.setEnabled(False)

        self.process = QProcess(self)
        self.process.setProcessChannelMode(
            QProcess.ProcessChannelMode.MergedChannels
        )

        self.process.readyReadStandardOutput.connect(self.read_output)
        self.process.finished.connect(self.install_finished)

        password_data = (password + "\n").encode()

        def send_password():
            self.process.write(password_data)
            self.process.closeWriteChannel()
            self.password.clear()
            self.password2.clear()

        self.process.started.connect(send_password)

        self.process.start(
            "/usr/bin/pkexec",
            [
                ENGINE,
                "--non-interactive",
                disk,
                username,
                keyboard,
            ],
        )

    def read_output(self):
        data = bytes(
            self.process.readAllStandardOutput()
        ).decode(errors="replace")

        if data:
            self.log.moveCursor(self.log.textCursor().MoveOperation.End)
            self.log.insertPlainText(data)
            self.log.ensureCursorVisible()

    def install_finished(self, exit_code, exit_status):
        self.install_button.setEnabled(True)
        self.refresh_button.setEnabled(True)

        if exit_code == 0:
            QMessageBox.information(
                self,
                "Instalación completada",
                "Sextante Linux se instaló correctamente.",
            )
        else:
            QMessageBox.critical(
                self,
                "Error de instalación",
                (
                    "La instalación no terminó correctamente.\n\n"
                    "Revisa el registro mostrado en la ventana."
                ),
            )


app = QApplication(sys.argv)
window = Installer()
window.show()
sys.exit(app.exec())
