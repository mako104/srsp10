enum ProjectStatus {
  active('Активный'),
  completed('Завершённый'),
  archived('Архивный');

  final String label;
  const ProjectStatus(this.label);
}

enum MemberRole {
  owner('Owner'),
  admin('Admin'),
  member('Member');

  final String label;
  const MemberRole(this.label);
}

enum TaskStatus {
  todo('Ожидает (Todo)'),
  inProgress('В работе'),
  done('Завершена'),
  cancelled('Отменена');

  final String label;
  const TaskStatus(this.label);
}

enum TaskPriority {
  low('Низкий'),
  medium('Средний'),
  high('Высокий'),
  critical('Критический');

  final String label;
  const TaskPriority(this.label);
}
