import re


emphasis_regex = re.compile('`([^`]+)`')
tag_regex = re.compile(r'#([a-zA-Z0-9_\-]+)')
contact_regex = re.compile(r'(?<!\w)@([a-zA-Z0-9_\-.]+)')
link_regex = re.compile(r'(?<!\w)\[([^"\]]+)\](?!\w)')


def escape_html(text):
    return (
        text
            .replace('<', '&lt;')
            .replace('>', '&gt;')
    )


def format_style(style):
    if style is None:
        return ''

    return (
        ' '.join(f'{key}: {style[key]};' for key in style)
            .replace('"', '\\"')
    )


class BulletFormatter:
    def __init__(self, style, bullets_formatter, text_formatter):
        self.style = style
        self.bullets_formatter = bullets_formatter
        self.text_formatter = text_formatter

    def to_html(self, bullet):
        style = self.build_style()

        content = self.text_formatter.to_html(bullet.content)
        children = self.build_children(bullet)

        return f'<li{style}>{content}{children}</li>'

    def build_children(self, bullet):
        if len(bullet.subbullets) == 0:
            return ''

        subbullets_html = ''.join(
            self.bullets_formatter.to_html(b) for b in bullet.subbullets
        )

        return f'<ul style="{format_style(BulletFormatter.list_style)}">{subbullets_html}</ul>'

    def build_style(self):
        if self.style:
            return f' style="{format_style(self.style)}"'

        return f' style="{format_style(BulletFormatter.default_style)}"'


BulletFormatter.default_style = {
    'color': 'initial',
    'font-weight': 'initial',
    'background-color': 'initial',
}

BulletFormatter.list_style = {
    'margin': '0',
    'margin-bottom': '5px',
}


class BulletsFormatter:
    def __init__(self, text_formatter):
        self.formatters = {}
        self.text_formatter = text_formatter
        self.default_formatter = None

    def register(self, bullet_types, style, *text_transforms):
        formatter = BulletFormatter(
            style,
            self,
            self.text_formatter.extend(*text_transforms),
        )

        for bt in bullet_types:
            self.formatters[bt] = formatter

    @staticmethod
    def default(text_formatter):
        bf = BulletsFormatter(text_formatter)

        bf.register('-', None)
        bf.register('*+', {'color': 'green'}, lambda s : f'<b>AP:</b> {s}')
        bf.register('?.', {'color': '#FF5722'})

        return bf

    def to_html(self, bullet):
        if bullet.bullet_type not in self.formatters:
            if self.default_formatter is None:
                return ''

            return self.default_formatter.to_html(bullet)

        formatter = self.formatters[bullet.bullet_type]

        return formatter.to_html(bullet)


contact_style = {
    'color': 'blue',
    'font-weight': 'bold',
    'text-decoration': 'underline',
}

contact_sub_pattern = f'<span style="{format_style(contact_style)}">\\1</span>'


class TextFormatter:
    def __init__(self, transforms):
        self.transforms = transforms

    @staticmethod
    def default():
        return TextFormatter([
            lambda s : emphasis_regex.sub(r'<b>\1</b>', s),
            lambda s : tag_regex.sub(r'<i>\1</i>', s),
            lambda s : (
                contact_regex
                    .sub(contact_sub_pattern, s)
                    .replace('_', ' ')
            ),
            lambda s : link_regex.sub(r'<a href="\1" target="_blank">\1</a>', s),
        ])

    def extend(self, *transforms):
        if len(transforms) == 0:
            return self

        return TextFormatter(
            self.transforms + list(transforms)
        )

    def to_html(self, text):
        interim = escape_html(text)

        for transform in self.transforms:
            interim = transform(interim)

        return interim


class SectionFormatter:
    def __init__(self, heading_style, bullets_formatter, text_formatter):
        self.heading_style = heading_style
        self.bullets_formatter = bullets_formatter
        self.text_formatter = text_formatter

    @staticmethod
    def default():
        tf = TextFormatter.default()
        return SectionFormatter(
            None,
            BulletsFormatter.default(tf),
            tf,
        )

    def to_html(self, section):
        output = []

        if section.title != '':
            formatted_title = self.text_formatter.to_html(section.title)
            output.append(f'<h2 style="{format_style(self.heading_style)}">{formatted_title}</h2>')

        for item in section.contents:
            if type(item) is str:
                formatted_text = self.text_formatter.to_html(item)
                output.append(f'<p>{formatted_text}</p>')
            else:
                output.append(self.bullets_formatter.to_html(item))

        return ''.join(output)


class DocumentFormatter:
    def __init__(self, header_style, section_formatter, text_formatter=None):
        self.header_style = header_style
        self.section_formatter = section_formatter
        self.text_formatter = text_formatter or section_formatter.text_formatter

    @staticmethod
    def default():
        return DocumentFormatter(
            None,
            SectionFormatter.default(),
        )

    def to_html(self, document):
        output = []

        if document.title != '':
            formatted_title = self.text_formatter.to_html(document.title)
            output.append(f'<h1 style="{format_style(self.header_style)}">{formatted_title}</h1>')

        output += [self.section_formatter.to_html(section) for section in document.sections]

        return ''.join(output)

    def to_full_html(self, document):
        inner_html = self.to_html(document)

        return f'<html><head></head><body>{inner_html}</body></html>'