import json
import math
from pathlib import Path

from reportlab.lib import colors
from reportlab.pdfbase.pdfmetrics import stringWidth
from reportlab.pdfgen import canvas


ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / "docs" / "database-schema-snapshot.json"
OUTPUT = ROOT / "output" / "pdf" / "DER_Barbearia_MySQL.pdf"

# A0 landscape in points. The large vector canvas remains readable when zoomed.
PAGE_W, PAGE_H = 3370.39, 2383.94
MARGIN = 70
TITLE_H = 125
FOOTER_H = 55
COLS = 5

BG = colors.HexColor("#F4F7FB")
INK = colors.HexColor("#162033")
MUTED = colors.HexColor("#5E6B7D")
BLUE = colors.HexColor("#1E5AA8")
BLUE_DARK = colors.HexColor("#123E75")
BLUE_LIGHT = colors.HexColor("#E8F1FD")
LINE = colors.HexColor("#9CAABD")
PK = colors.HexColor("#F2A93B")
FK = colors.HexColor("#39A67E")
WHITE = colors.white


def fit_text(text, max_width, font="Helvetica", size=8):
    text = str(text)
    if stringWidth(text, font, size) <= max_width:
        return text
    suffix = "..."
    while text and stringWidth(text + suffix, font, size) > max_width:
        text = text[:-1]
    return text + suffix


def main():
    data = json.loads(SNAPSHOT.read_text(encoding="utf-8"))
    tables = data["tables"]
    columns = data["columns"]
    foreign_keys = data["foreignKeys"]
    cols_by_table = {table["TABLE_NAME"]: [] for table in tables}
    for column in columns:
        cols_by_table[column["TABLE_NAME"]].append(column)

    fk_columns = {
        (fk["TABLE_NAME"], fk["COLUMN_NAME"]): fk for fk in foreign_keys
    }

    rows = math.ceil(len(tables) / COLS)
    gap_x, gap_y = 34, 30
    usable_w = PAGE_W - 2 * MARGIN
    usable_h = PAGE_H - MARGIN - TITLE_H - FOOTER_H
    box_w = (usable_w - gap_x * (COLS - 1)) / COLS
    cell_h = (usable_h - gap_y * (rows - 1)) / rows

    positions = {}
    for index, table in enumerate(tables):
        col = index % COLS
        row = index // COLS
        x = MARGIN + col * (box_w + gap_x)
        y_top = PAGE_H - MARGIN - TITLE_H - row * (cell_h + gap_y)
        positions[table["TABLE_NAME"]] = (x, y_top - cell_h, box_w, cell_h)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    pdf = canvas.Canvas(str(OUTPUT), pagesize=(PAGE_W, PAGE_H), pageCompression=1)
    pdf.setTitle("DER - Barbearia MySQL")
    pdf.setAuthor("Projeto Barbearia")

    pdf.setFillColor(BG)
    pdf.rect(0, 0, PAGE_W, PAGE_H, fill=1, stroke=0)

    pdf.setFillColor(INK)
    pdf.setFont("Helvetica-Bold", 34)
    pdf.drawString(MARGIN, PAGE_H - MARGIN, "DER - Banco de Dados Barbearia")
    pdf.setFillColor(MUTED)
    pdf.setFont("Helvetica", 15)
    subtitle = (
        f"MySQL / schema {data['database']}  |  {len(tables)} tabelas  |  "
        f"{len(columns)} colunas  |  {len(foreign_keys)} chaves estrangeiras"
    )
    pdf.drawString(MARGIN, PAGE_H - MARGIN - 31, subtitle)

    # Relationships are drawn first, so entity cards remain fully legible.
    pdf.saveState()
    pdf.setStrokeColor(LINE)
    pdf.setLineWidth(1.25)
    pdf.setDash(5, 4)
    for fk in foreign_keys:
        child = positions[fk["TABLE_NAME"]]
        parent = positions[fk["REFERENCED_TABLE_NAME"]]
        cx, cy = child[0] + child[2] / 2, child[1] + child[3] / 2
        px, py = parent[0] + parent[2] / 2, parent[1] + parent[3] / 2
        pdf.line(px, py, cx, cy)
        # Arrow head at the child side.
        dx, dy = cx - px, cy - py
        length = max((dx * dx + dy * dy) ** 0.5, 1)
        ux, uy = dx / length, dy / length
        ax, ay = cx - ux * min(child[2], child[3]) * 0.47, cy - uy * min(child[2], child[3]) * 0.47
        size = 7
        pdf.line(ax, ay, ax - ux * size - uy * size * 0.6, ay - uy * size + ux * size * 0.6)
        pdf.line(ax, ay, ax - ux * size + uy * size * 0.6, ay - uy * size - ux * size * 0.6)
    pdf.restoreState()

    header_h = 34
    padding = 12
    for table in tables:
        name = table["TABLE_NAME"]
        x, y, width, height = positions[name]
        table_columns = cols_by_table[name]
        row_h = min(15.5, (height - header_h - 13) / max(len(table_columns), 1))
        font_size = min(9.2, row_h * 0.66)

        pdf.setFillColor(WHITE)
        pdf.setStrokeColor(colors.HexColor("#CAD4E2"))
        pdf.setLineWidth(1.2)
        pdf.roundRect(x, y, width, height, 9, fill=1, stroke=1)
        pdf.setFillColor(BLUE_DARK)
        pdf.roundRect(x, y + height - header_h, width, header_h, 9, fill=1, stroke=0)
        pdf.rect(x, y + height - header_h, width, 9, fill=1, stroke=0)
        pdf.setFillColor(WHITE)
        pdf.setFont("Helvetica-Bold", 12.5)
        pdf.drawString(x + padding, y + height - 22, fit_text(name, width - 2 * padding, "Helvetica-Bold", 12.5))

        cursor_y = y + height - header_h - row_h + 3
        for idx, column in enumerate(table_columns):
            if idx % 2 == 0:
                pdf.setFillColor(colors.HexColor("#F8FAFD"))
                pdf.rect(x + 1, cursor_y - 3, width - 2, row_h, fill=1, stroke=0)

            is_pk = column["COLUMN_KEY"] == "PRI"
            is_fk = (name, column["COLUMN_NAME"]) in fk_columns
            marker = "PK/FK" if is_pk and is_fk else "PK" if is_pk else "FK" if is_fk else ""
            if marker:
                marker_color = PK if is_pk else FK
                pdf.setFillColor(marker_color)
                pdf.roundRect(x + padding, cursor_y, 34, row_h - 4, 3, fill=1, stroke=0)
                pdf.setFillColor(WHITE)
                pdf.setFont("Helvetica-Bold", max(5.8, font_size - 1.3))
                pdf.drawCentredString(x + padding + 17, cursor_y + 3, marker)

            text_x = x + padding + (42 if marker else 0)
            pdf.setFillColor(INK)
            pdf.setFont("Helvetica-Bold", font_size)
            available_name = width * 0.52 - (text_x - x)
            pdf.drawString(text_x, cursor_y + 2, fit_text(column["COLUMN_NAME"], available_name, "Helvetica-Bold", font_size))

            type_text = column["COLUMN_TYPE"]
            if column["IS_NULLABLE"] == "YES":
                type_text += " NULL"
            pdf.setFillColor(MUTED)
            pdf.setFont("Helvetica", font_size - 0.3)
            pdf.drawRightString(x + width - padding, cursor_y + 2, fit_text(type_text, width * 0.42, "Helvetica", font_size - 0.3))
            cursor_y -= row_h

    legend_y = 25
    pdf.setFont("Helvetica", 11)
    pdf.setFillColor(MUTED)
    pdf.drawString(MARGIN, legend_y, "Legenda: PK = chave primaria | FK = chave estrangeira | linha tracejada = relacionamento pai -> filho")
    pdf.drawRightString(PAGE_W - MARGIN, legend_y, "Fonte: information_schema do banco real")

    pdf.showPage()
    pdf.save()
    print(OUTPUT)


if __name__ == "__main__":
    main()
